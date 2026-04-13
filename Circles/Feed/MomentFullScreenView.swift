import SwiftUI

struct MomentFullScreenView: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let profile: Profile?
    var viewModel: FeedViewModel?
    var scrollToComments: Bool = false
    var onCaptionSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var swapped = false
    @State private var comments: [Comment] = []
    @State private var commentProfiles: [UUID: Profile] = [:]
    @State private var isLoadingComments = true
    @State private var newCommentText = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var editableCaption: String = ""
    @State private var isSavingCaption = false
    @FocusState private var captionFocused: Bool

    private var isOwnPost: Bool { item.userId == currentUserId }

    private var mainPhotoUrl: String {
        swapped ? (item.secondaryPhotoUrl ?? item.photoUrl) : item.photoUrl
    }
    private var pipPhotoUrl: String? {
        guard let secondary = item.secondaryPhotoUrl else { return nil }
        return swapped ? item.photoUrl : secondary
    }

    private var displayName: String {
        let preferred = profile?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return preferred.isEmpty ? item.userName : preferred
    }

    private var timestampLabel: String {
        relativeTimestamp(item.postedAt)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Photo with PiP
                            photoSection
                                .padding(.top, 52)

                            // Identity + reactions + caption
                            metaSection
                                .padding(.top, 12)
                                .padding(.horizontal, 16)

                            // Divider before comments
                            Rectangle()
                                .fill(Color.msGold.opacity(0.15))
                                .frame(height: 1)
                                .padding(.top, 14)

                            // Inline comments
                            commentsSection
                                .id("comments-anchor")
                        }
                        .padding(.bottom, 80)
                    }
                    .onAppear {
                        if scrollToComments {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("comments-anchor", anchor: .top) }
                            }
                        }
                    }
                }

                // Comment input bar — pinned at bottom
                commentInputBar
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: SwiftUI.Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .task {
            editableCaption = item.caption ?? ""
            await loadComments()
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        ZStack(alignment: .topLeading) {
            CachedAsyncImage(url: mainPhotoUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(hex: "243828")
                    .overlay(ProgressView().tint(Color.msGold))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipped()

            if let pipUrl = pipPhotoUrl {
                CachedAsyncImage(url: pipUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(hex: "243828")
                }
                .frame(width: 118, height: 157)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.msGold, lineWidth: 2)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { swapped.toggle() }
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 8)
    }

    // MARK: - Meta Section (Identity, Reactions, Caption)

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Identity row
            FeedIdentityHeader(
                avatarUrl: profile?.avatarUrl,
                displayName: displayName,
                circleName: isOwnPost ? nil : item.circleName,
                timestamp: timestampLabel,
                isOnTime: item.isOnTime,
                avatarSize: 36
            )

            // Own-post: shared circles pill
            if isOwnPost {
                Text("Shared with \(item.circleIds.count) Circle\(item.circleIds.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "1A2E1E"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.msGold, in: Capsule())
            }

            // Reactions row
            if let viewModel {
                HStack {
                    ReactionBar(
                        itemId: item.id, itemType: "moment",
                        currentUserId: currentUserId, viewModel: viewModel
                    )
                    Spacer()
                }
            }

            // Caption
            if isOwnPost {
                HStack(spacing: 8) {
                    TextField("Add a caption...", text: $editableCaption, axis: .vertical)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.msTextPrimary)
                        .lineLimit(1...4)
                        .tint(Color.msGold)
                        .focused($captionFocused)

                    if captionFocused {
                        Button {
                            Task { await saveCaption() }
                        } label: {
                            if isSavingCaption {
                                ProgressView().tint(Color.msGold).scaleEffect(0.7)
                            } else {
                                Text("Save")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.msGold)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.msTextPrimary)
            }

            // Error message (caption save or comment)
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.msGold)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else if comments.isEmpty {
                VStack(spacing: 6) {
                    Text("No comments yet")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                    Text("Be the first to say something.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(comments) { comment in
                        MomentCommentRow(
                            comment: comment,
                            profile: commentProfiles[comment.userId],
                            currentUserId: currentUserId,
                            onDelete: { Task { await deleteComment(comment) } }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(1...4)
                .padding(10)
                .background(Color.msGold.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                .tint(Color.msGold)

            Button {
                Task { await sendComment() }
            } label: {
                if isSending {
                    ProgressView().tint(Color.msGold).scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            newCommentText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.msGold.opacity(0.3)
                                : Color.msGold
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    private func saveCaption() async {
        isSavingCaption = true
        let trimmed = editableCaption.trimmingCharacters(in: .whitespaces)
        let newCaption: String? = trimmed.isEmpty ? nil : trimmed
        do {
            try await MomentService.shared.updateCaption(newCaption, userId: currentUserId)
            captionFocused = false
            // Optimistic in-memory update — instant, no network round-trip
            viewModel?.updateMomentCaption(momentId: item.id, caption: newCaption)
            onCaptionSaved?()
        } catch {
            errorMessage = "Couldn't save caption. Try again."
            print("[MomentFullScreenView] saveCaption failed: \(error)")
        }
        isSavingCaption = false
    }

    private func loadComments() async {
        isLoadingComments = true
        comments = (try? await CommentService.shared.fetchComments(postId: item.id, circleId: item.circleId)) ?? []
        let userIds = Array(Set(comments.map { $0.userId }))
        let profileList = (try? await AvatarService.shared.fetchProfiles(userIds: userIds)) ?? []
        commentProfiles = Dictionary(uniqueKeysWithValues: profileList.map { ($0.id, $0) })
        isLoadingComments = false
    }

    private func sendComment() async {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            let comment = try await CommentService.shared.addComment(
                postId: item.id,
                postType: "moment",
                circleId: item.circleId,
                userId: currentUserId,
                text: trimmed
            )
            comments.append(comment)
            newCommentText = ""
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

    private func relativeTimestamp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: iso) }()
        else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(max(1, Int(diff / 60)))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}

// MARK: - Comment Row (Midnight Sanctuary styled)

private struct MomentCommentRow: View {
    let comment: Comment
    let profile: Profile?
    let currentUserId: UUID
    let onDelete: () -> Void

    private var displayName: String {
        profile?.preferredName ?? String(comment.userId.uuidString.prefix(8))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(avatarUrl: profile?.avatarUrl, name: displayName, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(displayName)
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msTextPrimary)
                    Spacer()
                    if comment.userId == currentUserId {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.msTextMuted.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(comment.text)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
