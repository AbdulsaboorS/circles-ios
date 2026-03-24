import SwiftUI

struct CircleDetailView: View {
    let circle: Circle
    @State private var members: [HalaqaMember] = []
    @State private var isLoading = true

    private var inviteURL: URL {
        URL(string: "https://joinlegacy.app/join/\(circle.inviteCode ?? "")")!
    }

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()

            List {
                // Circle info header
                Section {
                    if let desc = circle.description, !desc.isEmpty {
                        Text(desc)
                            .foregroundStyle(.white.opacity(0.8))
                            .listRowBackground(Color.white.opacity(0.06))
                    }
                    if let prayer = circle.prayerTime, !prayer.isEmpty {
                        HStack {
                            Text("Circle Moment")
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text(prayer.capitalized)
                                .foregroundStyle(Color(hex: "E8834B"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "E8834B").opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                }

                // Invite section
                Section("Invite") {
                    if let code = circle.inviteCode {
                        HStack {
                            Text("Code:")
                                .foregroundStyle(.white.opacity(0.6))
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }

                    ShareLink(item: inviteURL) {
                        Label("Invite Friends", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color(hex: "E8834B"))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .foregroundStyle(.white.opacity(0.6))

                // Members section
                Section("Members (\(members.count))") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(Color(hex: "E8834B"))
                            Spacer()
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    } else {
                        ForEach(members) { member in
                            HStack {
                                Text(String(member.userId.uuidString.prefix(8)))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white)
                                Spacer()
                                if member.role == "admin" {
                                    Text("Admin")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "E8834B"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: "E8834B").opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "0D1021"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            do {
                members = try await CircleService.shared.fetchMembers(circleId: circle.id)
            } catch {
                // Non-critical: show empty members list on error
            }
            isLoading = false
        }
    }
}
