import SwiftUI

struct RamadanAmountView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        ScrollView {
            VStack(spacing: 20) {
                Text("How much did you do during Ramadan?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top)

                ForEach(coordinator.allSelectedNames, id: \.self) { name in
                    HStack {
                        Text(coordinator.icon(for: name)).font(.title2)
                        Text(name).font(.body.weight(.medium))
                        Spacer()
                        TextField("e.g. 5x daily", text: Binding(
                            get: { coord.ramadanAmounts[name] ?? "" },
                            set: { coord.ramadanAmounts[name] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                    }
                    .padding(.horizontal)
                }

                Button("Get AI Suggestions") {
                    coordinator.proceedToAI()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!coordinator.allAmountsEntered)
                .padding()
            }
        }
        .navigationTitle("Ramadan Habits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
