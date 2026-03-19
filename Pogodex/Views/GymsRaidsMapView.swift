import SwiftUI
import CoreLocation
import MapKit
import Combine

struct GymsRaidsMapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var pogodexViewModel: PogodexViewModel
    @StateObject private var locationManager = NearbyLocationManager()
    @StateObject private var viewModel = GymsRaidsMapViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    @State private var selectedGym: PogoMapGym?
    @State private var selectedHundo: PogoMapPokemon?
    @State private var showRaids = true
    @State private var showGyms = true
    @State private var showHundos = true
    @State private var teamFilter: Set<Int> = [0, 1, 2, 3]
    @State private var minIV: Double = 100.0
    @State private var searchText: String = ""
    @State private var isFilterSheetPresented = false
    @State private var reloadTask: Task<Void, Never>?
    @State private var timerTick = 0
    @State private var didInitialLoad = false
    @State private var gymTapTrigger = 0
    @State private var isMapActive = false

    private let countdownTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                mapAnnotations
            }
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
                    .accessibilityLabel("Centrer sur ma position")
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                debouncedReload(region: context.region)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .navigationTitle("Carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Filtres", systemImage: "line.3.horizontal.decrease.circle") {
                        isFilterSheetPresented = true
                    }
                    Button("Rafraichir", systemImage: "arrow.clockwise") {
                        reloadCurrentRegion()
                    }
                }
            }
        }
        .task {
            locationManager.requestPermissionIfNeeded()
            try? await Task.sleep(for: .seconds(3))
            if !didInitialLoad {
                didInitialLoad = true
                await viewModel.loadMap(in: visibleRegion, minIV: minIV)
            }
        }
        .onAppear {
            isMapActive = true
            locationManager.startUpdating()
        }
        .onDisappear {
            isMapActive = false
            reloadTask?.cancel()
            locationManager.stopUpdating()
        }
        .onChange(of: scenePhase) { _, newPhase in
            let shouldRun = newPhase == .active && isMapActive
            if shouldRun {
                locationManager.startUpdating()
            } else {
                locationManager.stopUpdating()
            }
        }
        .onChange(of: locationManager.lastLocation) { _, newLoc in
            guard isMapActive, scenePhase == .active else { return }
            guard let coord = newLoc?.coordinate else { return }
            if !didInitialLoad {
                didInitialLoad = true
                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                cameraPosition = .region(region)
                visibleRegion = region
                reloadCurrentRegion()
                return
            }

            guard isViewingCurrentLocation(coord) else {
                return
            }

            let oldCenter = visibleRegion.center
            let moved = abs(coord.latitude - oldCenter.latitude) + abs(coord.longitude - oldCenter.longitude)
            if moved > visibleRegion.span.latitudeDelta * 0.3 {
                let newRegion = MKCoordinateRegion(center: coord, span: visibleRegion.span)
                visibleRegion = newRegion
                debouncedReload(region: newRegion)
            }
        }
        .sheet(item: $selectedGym) { gym in
            GymDetailSheet(gym: gym, pokemonName: pokemonName(for:))
        }
        .sheet(item: $selectedHundo) { poke in
            HundoDetailSheet(poke: poke, pokemonName: pokemonName(for:))
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            MapFilterSheet(
                showRaids: $showRaids,
                showGyms: $showGyms,
                showWilds: $showHundos,
                teamFilter: $teamFilter,
                minIV: $minIV,
                searchText: $searchText,
                onApply: { debouncedReload() }
            )
        }
        .overlay(alignment: .top) {
            if let mapError = viewModel.mapError, !mapError.isEmpty {
                Text(mapError)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
        }
        .onReceive(countdownTimer) { _ in
            guard isMapActive, scenePhase == .active else { return }
            timerTick += 1
            if timerTick % 4 == 0 {
                debouncedReload()
            } else {
                let now = Date.now.timeIntervalSince1970
                for gym in viewModel.displayedGyms {
                    if let battle = gym.raidBattleTimestamp,
                       gym.raidPokemonId == nil || gym.raidPokemonId == 0 {
                        let diff = now - TimeInterval(battle)
                        if diff >= 0 && diff < 16 {
                            debouncedReload()
                            break
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: gymTapTrigger)
    }

    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        UserAnnotation()

        ForEach(filteredHundos) { poke in
            Annotation("", coordinate: poke.coordinate, anchor: .bottom) {
                HundoAnnotationView(poke: poke)
                    .contentShape(Rectangle())
                    .onTapGesture { selectHundo(poke) }
                    .accessibilityLabel("Pokemon sauvage \(pokemonName(for: poke.pokemonId)), IV \(poke.ivInt) pourcent")
            }
        }

        ForEach(filteredGyms) { gym in
            if gym.hasActiveRaid {
                Annotation(gym.name ?? "", coordinate: gym.coordinate, anchor: .bottom) {
                    RaidAnnotationView(
                        gym: gym,
                        pokemonName: pokemonName(for: gym.raidPokemonId ?? 0),
                        timerTick: timerTick
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectGym(gym) }
                    .accessibilityLabel("Raid \(gym.name ?? "Arene")")
                }
            } else {
                Annotation(gym.name ?? "Arene", coordinate: gym.coordinate) {
                    GymAnnotationView(gym: gym)
                        .contentShape(Rectangle())
                        .onTapGesture { selectGym(gym) }
                        .accessibilityLabel("Arene \(gym.name ?? "Arene")")
                }
            }
        }
    }

    private var filteredGyms: [PogoMapGym] {
        viewModel.displayedGyms.filter { gym in
            if gym.hasActiveRaid {
                return showRaids
            }
            return showGyms && teamFilter.contains(gym.teamId ?? 0)
        }
    }

    private var filteredHundos: [PogoMapPokemon] {
        guard showHundos else { return [] }
        return viewModel.displayedHundos.filter { poke in
            if !searchText.isEmpty {
                let name = pokemonName(for: poke.pokemonId)
                if !name.localizedStandardContains(searchText) {
                    return false
                }
            }
            return poke.iv >= minIV
        }
    }

    private func selectGym(_ gym: PogoMapGym) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectedGym = gym
        }
        gymTapTrigger += 1
    }

    private func selectHundo(_ poke: PogoMapPokemon) {
        selectedHundo = poke
    }

    private func reloadCurrentRegion() {
        reloadTask?.cancel()
        let region = visibleRegion
        let iv = minIV
        reloadTask = Task {
            await viewModel.loadMap(in: region, minIV: iv)
        }
    }

    private func debouncedReload(region: MKCoordinateRegion? = nil) {
        reloadTask?.cancel()
        let regionToUse = region ?? visibleRegion
        let iv = minIV
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await viewModel.loadMap(in: regionToUse, minIV: iv)
        }
    }

    private func pokemonName(for dexNr: Int) -> String {
        pogodexViewModel.pokemons.first { $0.dexNr == dexNr }?.name ?? "Pokemon #\(dexNr)"
    }

    private func isViewingCurrentLocation(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeDistance = abs(coordinate.latitude - visibleRegion.center.latitude)
        let longitudeDistance = abs(coordinate.longitude - visibleRegion.center.longitude)

        return latitudeDistance <= visibleRegion.span.latitudeDelta * 0.6 &&
            longitudeDistance <= visibleRegion.span.longitudeDelta * 0.6
    }

}
