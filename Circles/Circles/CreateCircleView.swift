import SwiftUI
import Supabase

struct CreateCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var selectedPrayerTime = "fajr"
    @State private var isCreating = false

    private let prayerTimes = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1021").ignoresSafeArea()

                Form {
                    Section("Circle Info") {
                        TextField("Circle name", text: $name)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(.white)
                            .listRowBackground(Color.white.opacity(0.08))

                        TextField("What's this circle about?", text: $description)
                            .textInputAutocapitalization(.sentences)
                            .foregroundStyle(.white)
                            .listRowBackground(Color.white.opacity(0.08))
                    }
                    .foregroundStyle(.white.opacity(0.6))

                    Section("Circle Moment Prayer") {
                        Picker("Prayer Time", selection: $selectedPrayerTime) {
                            ForEach(prayerTimes, id: \.self) { prayer in
                                Text(prayer.capitalized).tag(prayer)
                            }
                        }
                        .pickerStyle(.wheel)
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "E8834B"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            isCreating = true
                            if let userId = auth.session?.user.id {
                                let result = await viewModel.createCircle(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    description: description.isEmpty ? nil : description,
                                    prayerTime: selectedPrayerTime,
                                    userId: userId
                                )
                                if result != nil { dismiss() }
                            }
                            isCreating = false
                        }
                    }
                    .foregroundStyle(Color(hex: "E8834B"))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
