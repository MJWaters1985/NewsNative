//
//  DiscoverFeedsView.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Main View

@available(iOS 15.0, *)
struct DiscoverFeedsView: View {
    @ObservedObject var viewModel: DiscoverFeedsViewModel
    @ObservedObject var cardActions: DiscoverSitesViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            if cardActions.isAdding || cardActions.isPreparingPreview {
                ProgressView(cardActions.isAdding ? NBLocalization.text("Adding site…") : NBLocalization.text("Opening site…"))
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.textPrimary)
                    .padding(12)
            }
            if let error = cardActions.addErrorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.errorText)
                    .padding(12)
            }
            if cardActions.addedSuccess {
                Label(NBLocalization.text("Site added"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.accent)
                    .padding(12)
                    .accessibilityIdentifier("related-site-added-success")
            }
            contentView
        }
        .environmentObject(cardActions)
        .background(DiscoverColors.background)
        .id(themeObserver.themeVersion)
        .onAppear {
            viewModel.loadInitialPage()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        headerTitle
                        Spacer(minLength: 8)
                        viewModePicker
                        closeButton
                    }
                    stackedHeader
                }
            } else {
                stackedHeader
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(DiscoverColors.cardBackground)
    }

    private var stackedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                headerTitle
                Spacer()
                closeButton
            }
            viewModePicker
        }
    }

    private var headerTitle: some View {
        HStack {
            Image("discover")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(DiscoverColors.textSecondary)
            Text(NBLocalization.text("Related sites"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var viewModePicker: some View {
        DiscoverViewModePicker(viewMode: Binding(
            get: { viewModel.viewMode }, set: { viewModel.setViewMode($0) }))
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NBLocalization.text("Close Related Sites"))
        .hoverEffect(.highlight)
    }

    // MARK: - Content

    private var contentView: some View {
        Group {
            if viewModel.feeds.isEmpty && viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error, viewModel.feeds.isEmpty {
                errorView(error)
            } else {
                feedListView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
            Text(NBLocalization.text("Finding related sites..."))
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(DiscoverColors.textSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                LazyVGrid(columns: [viewModel.viewMode == .grid
                    ? GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)
                    : GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.feeds) { feed in
                        DiscoverFeedCardView(feed: feed, showStories: viewModel.viewMode == .list,
                                             onTryFeed: onTryFeed, onOpenStory: onOpenStory, onAddFeed: onAddFeed)
                    }
                }

                if viewModel.hasMorePages {
                    loadMoreIndicator
                }
            }
            .padding(12)
        }
    }

    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                    .padding(.vertical, 16)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        viewModel.loadNextPage()
                    }
            }
            Spacer()
        }
    }

}
