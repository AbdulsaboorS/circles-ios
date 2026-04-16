import SwiftUI
import PhotosUI

struct ProfileHeroSection: View {
    let viewModel: ProfileViewModel
    let displayName: String
    let memberSince: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isEditingName: Bool
    @Binding var editNameDraft: String
    let onSaveName: () async -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed cover photo
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                coverPhoto
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Islamic pattern overlay on photo
            IslamicGeometricPattern(opacity: 0.035, tileSize: 48, color: Color.msGold)
                .frame(height: 320)
                .clipped()

            // Bottom gradient — fades photo into the page background
            LinearGradient(
                colors: [.clear, Color.msBackground.opacity(0.5), Color.msBackground],
                startPoint: .init(x: 0.5, y: 0.3),
                endPoint: .bottom
            )
            .frame(height: 320)

            // Name + member since overlaid at bottom-left
            VStack(alignment: .leading, spacing: 5) {
                if isEditingName {
                    HStack(spacing: 8) {
                        TextField("Your name", text: $editNameDraft)
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                            .textInputAutocapitalization(.words)
                            .tint(Color.msGold)
                            .frame(maxWidth: 220)
                        Button {
                            Task {
                                await onSaveName()
                                isEditingName = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.msGold)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Button {
                            editNameDraft = displayName
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.msGold.opacity(0.7))
                        }
                    }
                }

                if !memberSince.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.msGold)
                        Text(memberSince)
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Upload spinner / camera badge — top-right
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        SwiftUI.Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 34, height: 34)
                        if viewModel.isUploadingAvatar {
                            ProgressView().tint(Color.msTextPrimary).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.msTextPrimary)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            .frame(height: 320)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var coverPhoto: some View {
        if let urlString = viewModel.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        ZStack {
            Color.msCardShared
            VStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.msTextMuted.opacity(0.4))
                Text("Tap to add a photo")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted.opacity(0.6))
            }
        }
    }
}
