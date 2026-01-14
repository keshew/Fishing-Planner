import SwiftUI

// MARK: - Models
struct Trip: Identifiable, Codable {
    let id = UUID()
    var name: String
    var date: Date
    var location: String
    var fishingType: FishingType
    var targetFish: String?
    var notes: String?
    var isCompleted: Bool
    var checklist: [ChecklistItem]
    
    enum FishingType: String, CaseIterable, Codable {
        case ice = "Ice"
        case shore = "Shore"
        case boat = "Boat"
    }
}

struct ChecklistItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var isCompleted: Bool
}

// MARK: - Store
@MainActor
class TripStore: ObservableObject {
    @Published var trips: [Trip] = []
    private let tripsKey = "savedTrips"
    
    init() {
        loadTrips()
    }
    
    func saveTrip(_ trip: Trip) {
        trips.append(trip)
        saveToUserDefaults()
    }
    
    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveToUserDefaults()
        }
    }
    
    func deleteTrip(_ id: UUID) {
        trips.removeAll { $0.id == id }
        saveToUserDefaults()
    }
    
    func markCompleted(_ id: UUID) {
        if let index = trips.firstIndex(where: { $0.id == id }) {
            trips[index].isCompleted = true
            saveToUserDefaults()
        }
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: tripsKey)
        }
    }
    
    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: tripsKey),
           let decodedTrips = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = decodedTrips
        }
    }
}

// MARK: - ContentView (TabBar)
struct ContentView: View {
    @StateObject private var tripStore = TripStore()
    
    var body: some View {
        TabView {
            TripsView()
                .environmentObject(tripStore)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Trips")
                }
            
            ChecklistView()
                .environmentObject(tripStore)
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("Checklist")
                }
            
            CalendarView()
                .environmentObject(tripStore)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            SettingsView()
                .environmentObject(tripStore)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
        .tint(.blue)
    }
}

// MARK: - TripsView
struct TripsView: View {
    @EnvironmentObject var tripStore: TripStore
    @State private var showingNewTrip = false
    @State private var filter: TripFilter = .upcoming
    
    enum TripFilter {
        case upcoming, past, all
    }
    
    var filteredTrips: [Trip] {
        switch filter {
        case .upcoming:
            return tripStore.trips.filter { !$0.isCompleted }
        case .past:
            return tripStore.trips.filter { $0.isCompleted }
        case .all:
            return tripStore.trips
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Фильтр
                HStack {
                    Text("Filter")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("Filter", selection: $filter) {
                        Text("Up.").tag(TripFilter.upcoming)
                        Text("Past").tag(TripFilter.past)
                        Text("All").tag(TripFilter.all)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Список поездок
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if filteredTrips.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                Text("No trips yet")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("Tap + to plan your first fishing trip")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ForEach(filteredTrips) { trip in
                                TripCardView(trip: trip)
                                    .environmentObject(tripStore)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewTrip = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripView()
                    .environmentObject(tripStore)
            }
        }
    }
}

// MARK: - TripCardView
struct TripCardView: View {
    let trip: Trip
    @EnvironmentObject var tripStore: TripStore
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(trip.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(trip.location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(trip.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            TripDetailsView(trip: trip)
                .environmentObject(tripStore)
        }
    }
    
    private var statusBadge: some View {
        Text(trip.isCompleted ? "Completed" : "Planned")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(trip.isCompleted ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
            .foregroundColor(trip.isCompleted ? .green : .blue)
            .cornerRadius(20)
    }
}

// MARK: - NewTripView
struct NewTripView: View {
    @EnvironmentObject var tripStore: TripStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var fishingType: Trip.FishingType = .shore
    @State private var targetFish = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("New Trip")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Plan your fishing adventure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Trip Details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trip Details")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.blue)
                                    TextField("Trip name", text: $name)
                                        .font(.body)
                                }
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    DatePicker("Date", selection: $date, displayedComponents: .date)
                                        .font(.body)
                                }
                                
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.blue)
                                    TextField("Location", text: $location)
                                        .font(.body)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Fishing
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fishing")
                                .font(.headline)
                            
                            Picker("Fishing type", selection: $fishingType) {
                                ForEach(Trip.FishingType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            HStack {
                                Image(systemName: "fish")
                                    .foregroundColor(.blue)
                                TextField("Target fish (optional)", text: $targetFish)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button("Save Trip") {
                        let checklist = [
                            ChecklistItem(name: "Rod", isCompleted: false),
                            ChecklistItem(name: "Tackle", isCompleted: false),
                            ChecklistItem(name: "Baits", isCompleted: false),
                            ChecklistItem(name: "Clothes", isCompleted: false),
                            ChecklistItem(name: "Food", isCompleted: false)
                        ]
                        
                        let trip = Trip(
                            name: name,
                            date: date,
                            location: location,
                            fishingType: fishingType,
                            targetFish: targetFish.isEmpty ? nil : targetFish,
                            notes: notes.isEmpty ? nil : notes,
                            isCompleted: false,
                            checklist: checklist
                        )
                        tripStore.saveTrip(trip)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || location.isEmpty)
                    
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - TripDetailsView
struct TripDetailsView: View {
    let trip: Trip
    @EnvironmentObject var tripStore: TripStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text(trip.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                        Text(trip.location)
                        Spacer()
                        Text(trip.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Fishing type
                        HStack {
                            Image(systemName: "figure.outdoor.roller.skate")
                                .foregroundColor(.blue)
                            Text("Fishing type: \(trip.fishingType.rawValue)")
                                .font(.body)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        if let targetFish = trip.targetFish {
                            HStack {
                                Image(systemName: "fish")
                                    .foregroundColor(.green)
                                Text("Target: \(targetFish)")
                                    .font(.body)
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Checklist
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Checklist")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            ForEach(trip.checklist) { item in
                                HStack {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isCompleted ? .green : .gray)
                                    Text(item.name)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        if let notes = trip.notes {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") {
                        // TODO
                    }
                }
                ToolbarItem {
                    Button(trip.isCompleted ? "Completed" : "Mark Complete") {
                        tripStore.markCompleted(trip.id)
                        dismiss()
                    }
                    .tint(trip.isCompleted ? .green : .blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        // TODO
                    }
                    .tint(.red)
                }
            }
        }
    }
}

// MARK: - ChecklistView (Полная реализация)
struct ChecklistView: View {
    @EnvironmentObject var tripStore: TripStore
    @State private var checklistItems: [ChecklistItem] = []
    @State private var newItemName = ""
    @State private var showingForTrip = false
    @State private var selectedTrip: Trip?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Checklist")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Prepare for your trip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Upcoming trips checklist
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upcoming trips")
                        .font(.headline)
                    
                    if let nextTrip = tripStore.trips.first(where: { !$0.isCompleted }) {
                        TripChecklistPreview(trip: nextTrip)
                            .environmentObject(tripStore)
                    } else {
                        Text("No upcoming trips")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Global checklist editor
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your Checklist")
                            .font(.headline)
                        Spacer()
                        Button("Clear All") {
                            checklistItems.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    // Add new item
                    HStack {
                        TextField("Add item", text: $newItemName)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.bottom)
                    
                    // Checklist items
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if checklistItems.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("Checklist is empty")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                    Text("Add items you need for fishing")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, maxHeight: 200)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            } else {
                                ForEach(checklistItems) { item in
                                    ChecklistRow(item: item) { updatedItem in
                                        if let index = checklistItems.firstIndex(where: { $0.id == item.id }) {
                                            checklistItems[index] = updatedItem
                                            saveChecklist()
                                        }
                                    } onDelete: {
                                        checklistItems.removeAll { $0.id == item.id }
                                        saveChecklist()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save to Trip") {
                        showingForTrip = true
                    }
                    .disabled(tripStore.trips.isEmpty)
                }
            }
            .sheet(isPresented: $showingForTrip) {
                TripChecklistSelector(tripStore: tripStore, checklistItems: checklistItems)
            }
            .onAppear {
                loadChecklist()
            }
        }
    }
    
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            let item = ChecklistItem(name: trimmedName, isCompleted: false)
            checklistItems.append(item)
            saveChecklist()
            newItemName = ""
        }
    }
    
    private func saveChecklist() {
        if let data = try? JSONEncoder().encode(checklistItems) {
            UserDefaults.standard.set(data, forKey: "globalChecklist")
        }
    }
    
    private func loadChecklist() {
        if let data = UserDefaults.standard.data(forKey: "globalChecklist"),
           let decodedItems = try? JSONDecoder().decode([ChecklistItem].self, from: data) {
            checklistItems = decodedItems
        } else {
            // Default items
            checklistItems = [
                ChecklistItem(name: "Rod", isCompleted: false),
                ChecklistItem(name: "Tackle", isCompleted: false),
                ChecklistItem(name: "Baits", isCompleted: false),
                ChecklistItem(name: "Clothes", isCompleted: false),
                ChecklistItem(name: "Food", isCompleted: false)
            ]
        }
    }
}

// MARK: - ChecklistRow
struct ChecklistRow: View {
    let item: ChecklistItem
    let onUpdate: (ChecklistItem) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                var updatedItem = item
                updatedItem.isCompleted.toggle()
                onUpdate(updatedItem)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(item.isCompleted ? .blue : .secondary)
            }
            
            Text(item.name)
                .font(.body)
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - TripChecklistPreview
struct TripChecklistPreview: View {
    let trip: Trip
    @EnvironmentObject var tripStore: TripStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trip.name)
                    .font(.headline)
                Spacer()
                Text(trip.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Checklist progress
            HStack {
                Text("\(completedCount)/\(trip.checklist.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("items ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(Double(completedCount) / Double(trip.checklist.count) * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // Checklist items preview
            LazyVStack(spacing: 6) {
                ForEach(Array(trip.checklist.prefix(3))) { item in
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(item.isCompleted ? .green : .secondary)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if trip.checklist.count > 3 {
                    HStack {
                        Text("+\(trip.checklist.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var completedCount: Int {
        trip.checklist.filter { $0.isCompleted }.count
    }
}

// MARK: - TripChecklistSelector
struct TripChecklistSelector: View {
    let tripStore: TripStore
    let checklistItems: [ChecklistItem]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTripIndex = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Save checklist to trip")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select trip")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(tripStore.trips.enumerated()), id: \.offset) { index, trip in
                                if !trip.isCompleted {
                                    Button(action: { selectedTripIndex = index }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(trip.name)
                                                    .font(.headline)
                                                Text(trip.location)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: selectedTripIndex == index ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedTripIndex == index ? .blue : .secondary)
                                        }
                                        .padding()
                                        .background(selectedTripIndex == index ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Button("Apply Checklist") {
                    if selectedTripIndex < tripStore.trips.count {
                        var trip = tripStore.trips[selectedTripIndex]
                        trip.checklist = checklistItems
                        tripStore.updateTrip(trip)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTripIndex >= tripStore.trips.count)
            }
            .padding()
            .navigationTitle("Apply Checklist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}


// MARK: - CalendarView (Полная реализация)
struct CalendarView: View {
    @EnvironmentObject var tripStore: TripStore
    @State private var selectedDate = Date()
    @State private var selectedMonth = Date()
    @State private var showingTripsForDate = false
    @State private var tripsForDate: [Trip] = []
    
    private var calendarDays: [CalendarDay] {
        generateCalendarDaysForMonth(of: selectedMonth)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header с месяцем
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Calendar")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text(monthYearString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        // Upcoming trips count
                        let upcomingCount = tripStore.trips.filter { !$0.isCompleted }.count
                        if upcomingCount > 0 {
                            Button("\(upcomingCount) trips") {
                                selectedMonth = Date()
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Month navigation
                HStack {
                    Button {
                        selectedMonth = Calendar.current.date(
                            byAdding: .month,
                            value: -1,
                            to: selectedMonth
                        ) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedMonth = Date()
                    } label: {
                        Text("Today")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedMonth = Calendar.current.date(
                            byAdding: .month,
                            value: 1,
                            to: selectedMonth
                        ) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color(.systemGray5))
                
                // Calendar grid
                VStack {
                    // Weekday headers
                    HStack(spacing: 4) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Days grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(calendarDays) { day in
                            CalendarDayView(
                                day: day,
                                selectedDate: $selectedDate,
                                tripsCount: tripsOnDate(day.date).count
                            ) {
                                selectedDate = day.date
                                tripsForDate = tripsOnDate(day.date)
                                showingTripsForDate = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingTripsForDate) {
                TripsForDateView(
                    trips: tripsForDate,
                    date: selectedDate,
                    tripStore: tripStore
                )
            }
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private func tripsOnDate(_ date: Date) -> [Trip] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return tripStore.trips.filter { trip in
            !trip.isCompleted &&
            calendar.isDate(trip.date, equalTo: date, toGranularity: .day)
        }
    }
    
    private func generateCalendarDaysForMonth(of date: Date) -> [CalendarDay] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
        
        let days = (0..<calendar.dateComponents([.day], from: startOfMonth, to: endOfMonth).day!)
            .compactMap { day -> Date? in
                calendar.date(byAdding: .day, value: day, to: startOfMonth)
            }
        
        // Добавляем дни предыдущего/следующего месяца для заполнения сетки
        let firstDayWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysToAddBefore = (firstDayWeekday - 1 + 7) % 7
        
        let lastDayWeekday = calendar.component(.weekday, from: endOfMonth.addingTimeInterval(-1))
        let daysToAddAfter = (7 - lastDayWeekday) % 7
        
        var calendarDays: [CalendarDay] = []
        
        // Дни предыдущего месяца
        if daysToAddBefore > 0 {
            if let previousMonthDate = calendar.date(byAdding: .day, value: -daysToAddBefore, to: startOfMonth) {
                for dayOffset in 0..<daysToAddBefore {
                    if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: previousMonthDate) {
                        calendarDays.append(CalendarDay(date: dayDate, isCurrentMonth: false))
                    }
                }
            }
        }
        
        // Дни текущего месяца
        for day in days {
            calendarDays.append(CalendarDay(date: day, isCurrentMonth: true))
        }
        
        // Дни следующего месяца
        if daysToAddAfter > 0 {
            for dayOffset in 0..<daysToAddAfter {
                if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfMonth) {
                    calendarDays.append(CalendarDay(date: dayDate, isCurrentMonth: false))
                }
            }
        }
        
        return calendarDays
    }
}

// MARK: - CalendarDay
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
}

// MARK: - CalendarDayView
struct CalendarDayView: View {
    let day: CalendarDay
    @Binding var selectedDate: Date
    let tripsCount: Int
    let onTap: () -> Void
    
    private var isSelected: Bool {
        Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
    }
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: day.date)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Group {
                    Text("\(dayNumber)")
                        .font(.caption)
                        .fontWeight(isSelected ? .bold : .medium)
                        .padding(.horizontal, 10)
                        .foregroundColor(textColor)
                  
                }
                .frame(height: 32)
                
                if tripsCount > 0 {
                    Image(systemName: "fish")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .frame(height: 54, alignment: .top)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if day.isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if day.isCurrentMonth {
            return Color(.systemGray6)
        } else {
            return Color.clear
        }
    }
}

// MARK: - TripsForDateView
struct TripsForDateView: View {
    let trips: [Trip]
    let date: Date
    @ObservedObject var tripStore: TripStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text(date, style: .date)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(trips.count) trip\(trips.count == 1 ? "" : "s") planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                if trips.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No trips")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Plan your fishing trips here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(trips) { trip in
                                TripCardView(trip: trip)
                                    .environmentObject(tripStore)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}


// MARK: - SettingsView (Полная реализация)
struct SettingsView: View {
    @EnvironmentObject var tripStore: TripStore
    @State private var showingResetAlert = false
    @State private var showingExportAlert = false
    @State private var showingPrivacy = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("tripNotifications") private var tripNotifications = true
    @AppStorage("autoBackup") private var autoBackup = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Settings")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("App preferences")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Statistics")
                                .font(.headline)
                            
                            HStack {
                                StatCardView(
                                    title: "Total trips",
                                    value: "\(tripStore.trips.count)",
                                    icon: "calendar.badge.clock",
                                    color: .blue
                                )
                                
                                StatCardView(
                                    title: "Completed",
                                    value: "\(tripStore.trips.filter { $0.isCompleted }.count)",
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: "fish")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Fishing Trip Planner")
                                        .font(.headline)
                                    Text("v1.0.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Privacy Policy") {
                                    showingPrivacy = true
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all your trips, checklists and settings. This action cannot be undone.")
            }
            .alert("Export Data", isPresented: $showingExportAlert) {
                Button("Export") {
                    exportData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Trips will be exported as CSV file to Files app.")
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyPolicyView()
            }
        }
    }
    
    private func resetAllData() {
        tripStore.trips.removeAll()
        UserDefaults.standard.removeObject(forKey: "savedTrips")
        UserDefaults.standard.removeObject(forKey: "globalChecklist")
        UserDefaults.standard.set(false, forKey: "isDarkMode")
        UserDefaults.standard.set(false, forKey: "tripNotifications")
        UserDefaults.standard.set(false, forKey: "autoBackup")
        isDarkMode = false
        tripNotifications = false
        autoBackup = false
    }
    
    private func exportData() {
        let csvContent = generateCSV()
        print("📤 Export CSV:\n\(csvContent)")
    }
    
    private func generateCSV() -> String {
        var csv = "Trip Name,Date,Location,Fishing Type,Target Fish,Status\n"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        for trip in tripStore.trips {
            csv += "\"\(trip.name)\",\"\(formatter.string(from: trip.date))\",\"\(trip.location)\",\"\(trip.fishingType.rawValue)\",\"\(trip.targetFish ?? "")\",\"\(trip.isCompleted ? "Completed" : "Planned")\"\n"
        }
        return csv
    }
}

// MARK: - Settings Components
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            
            
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .cornerRadius(12)
        }
    }
}

struct ToggleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ButtonCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .foregroundColor(color == .red ? .red : .primary)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PrivacyPolicyView
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Fishing Trip Planner")
                        .font(.title2)
                    
                    Text("Your data stays on your device")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("• All trips, checklists and settings are stored locally using UserDefaults")
                        Text("• No data is sent to servers or third parties")
                        Text("• No user tracking or analytics")
                        Text("• No network permissions required")
                        Text("• Export feature saves CSV to your Files app")
                    }
                    .font(.body)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}


// MARK: - Extension для cornerRadius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Previews
#Preview {
    ContentView()
}
