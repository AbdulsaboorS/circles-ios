import SwiftUI
import Supabase

struct CommentDrawerView: View {
    let postId: UUID
    let postType: String
    let circleId: UUID
    let currentUserId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var profiles: [UUID: Profile] = [:]
    @State private var isLoading = true
    @State private var newText = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.darkBackground : Color.lightBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Comments list
                    if isLoading {
                        Spacer()
                        ProgressView().tint(Color.accent)
                        Spacer()
                    } else if comments.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accent.opacity(0.5))
                            Text("No comments yet.")
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textSecondary)
                            Text("Be the first to say something.")
                                .font(.appCaption)
                                .foregroundStyle(colors.textSecondary.opacity(0.6))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(comments) { comment in
                                    CommentRow(
                                        comment: comment,
                                        profile: profiles[comment.userId],
                                        currentUserId: currentUserId,
                                        onDelete: {
                                            Task { await deleteComment(comment) }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }

                    // Input bar
                    HStack(spacing: 10) {
                        TextField("Add a comment…", text: $newText, axis: .vertical)
                            .font(.appSubheadline)
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1...4)
                            .padding(10)
                            .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                            .tint(Color.accent)

                        Button {
                            Task { await sendComment() }
                        } label: {
                            if isSending {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(
                                        newText.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.accent.opacity(0.3)
                                            : Color.accent
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .task { await loadComments() }
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        comments = (try? await CommentService.shared.fetchComments(postId: postId, circleId: circleId)) ?? []
        // Load profiles for display names
        let userIds = Array(Set(comments.map { $0.userId }))
        let profileList = (try? await AvatarService.shared.fetchProfiles(userIds: userIds)) ?? []
        profiles = Dictionary(uniqueKeysWithValues: profileList.map { ($0.id, $0) })
        isLoading = false
    }

    private func sendComment() async {
        let trimmed = newText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            let comment = try await CommentService.shared.addComment(
                postId: postId,
                postType: postType,
                circleId: circleId,
                userId: currentUserId,
                text: trimmed
            )
            comments.append(comment)
            newText = ""
        } catch {
            errorMessage = "Couldn't send. Try again."
        }
        isSending = false
    }

    private func deleteComment(_ comment: Comment) async {
        guard comment.userId == currentUserId else { return }
        try? await CommentService.shared.deleteComment(commentId: comment.id)
        comments.removeAll { $0.id == comment.id }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let comment: Comment
    let profile: Profile?
    let currentUserId: UUID
    let onDelete: () -> Void

    private var displayName: String {
        profile?.preferredName ?? String(comment.userId.uuidString.prefix(8))
    }

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(avatarUrl: profile?.avatarUrl, name: displayName, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(displayName)
                        .font(.appCaptionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    if comment.userId == currentUserId {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(colors.textSecondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(comment.text)
                    .font(.appCaption)
                    .foregroundStyle(colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
