//
//  ContentView.swift
//  Seer
//
//  Created by Jacob Davis on 10/30/22.
//

import SwiftUI
import NostrKit
import RealmSwift
import AVKit
import AZVideoPlayer
import SimpleToast

struct HomeView: View {
    
    enum TextNotesFilter: String {
        case global = "Global"
        case following = "Following"
    }
    
    @EnvironmentObject var nostrData: NostrData
    @EnvironmentObject var navigation: Navigation
    
    @ObservedResults(TextNoteVM.self,
                     sortDescriptor: SortDescriptor(keyPath: "createdAt",
                                                    ascending: false)) var textNoteResults
    
    var textNotes: [TextNoteVM] {
        return Array(textNoteResults.filter("createdAt < %@", nostrData.lastSeenDate).prefix(250))
    }
    
    var newTextNotes: [TextNoteVM] {
        return Array(textNoteResults.filter("createdAt > %@", nostrData.lastSeenDate))
    }

    @State private var textNotesFilter: TextNotesFilter = .global
    @State private var scrollChange: Int = 0
    @State private var viewIsVisible = true
    @State private var date: Date = Date()
    
    let homeTapped = NotificationCenter.default.publisher(for: NSNotification.Name("HomeTapped"))

    var body: some View {
        NavigationStack(path: $navigation.homePath) {
            
            ScrollViewReader { reader in
                
                List {
                    ForEach(textNotes) { textNote in
                        TextNoteListView(textNote: textNote)
                            .padding()
                            .cardStyle()
                            .id(textNote.id)
                    }
                }
                //.scrollIndicators(.hidden)
                #if os(iOS)
                .background(Color(UIColor.systemGroupedBackground))
                #endif
                .listStyle(.plain)
                .background(.orange)
                .scrollContentBackground(.hidden)
                .navigationTitle(textNotesFilter.rawValue)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Navigation.NavUserProfile.self) { nav in
                    ProfileDetailView(userProfile: nav.userProfile)
                }
                .navigationDestination(for: Navigation.NavFollowing.self) { nav in
                    FollowingView(userProfile: nav.userProfile)
                }
                .navigationDestination(for: Navigation.NavFollowers.self) { nav in
                    FollowersView(userProfile: nav.userProfile)
                }
                .toolbar {
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        
                      //  if let _ = loggedInUser?.profileEntryResponse {
                            Menu {
                                Button(action: {
                                    self.textNotesFilter = .global
    //                                Task {
    //                                    await appState.setPostsFilter(.global)
    //                                }
    //                                scrollChange += 1
                                }) {
                                    Label("Global", systemImage: "globe.americas")
                                }

                                Button(action: {
                                    self.textNotesFilter = .following
    //                                Task {
    //                                    await appState.setPostsFilter(.following)
    //                                }
    //                                scrollChange += 1
                                }) {
                                    Label("Following", systemImage: "person.fill.checkmark")
                                }
                            }
                            label: {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                       // }

                    }
                    
    //                ToolbarItem(placement: .navigationBarTrailing) {
    //
    //                    if let _ = loggedInUser?.profileEntryResponse {
    //
    //                        Menu {
    //                            Button(action: {
    //
    //                            }) {
    //                                Label("Create Post", systemImage: "doc.text.image")
    //                            }
    //
    //                            Button(action: {}) {
    //                                Label("Create NFT", systemImage: "photo.on.rectangle.angled")
    //                            }
    //                        }
    //                        label: {
    //                            Label("Add", systemImage: "plus")
    //                        }
    //
    //                    }
    //
    //                }
                    
                }
                .simpleToast(isPresented: .constant(newTextNotes.count > 0),
                             options: SimpleToastOptions(alignment: .top, animation: .spring(), modifierType: .skew), onDismiss: nil) {
                    NewPostsToastView(avatarUrls: newTextNotes.prefix(3).map({ $0.userProfile?.avatarUrl ?? URL(string: "")! }))
                        .onTapGesture {
                            nostrData.updateLastSeenDate()
                            scrollChange += 1
                        }
                    }
                .onReceive(homeTapped) { (output) in
                    //
                    if !navigation.homePath.isEmpty {
                        navigation.homePath.removeLast()
                    } else {
                        NostrData.shared.updateLastSeenDate()
                    }
                    scrollChange += 1
                }
                .onChange(of: scrollChange) { value in
                    if viewIsVisible {
                        withAnimation {
                            reader.scrollTo(textNotes.first?.id, anchor: .top)
                        }
                    }
                }
                .onDisappear {
                    viewIsVisible = false
                }
                .onAppear {
                    viewIsVisible = true
                }
                .refreshable {
                    NostrData.shared.updateLastSeenDate()
                }
            }

        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(Navigation())
            .environmentObject(NostrData.shared.initPreview())
    }
}

import SDWebImageSwiftUI

struct TextNoteListView: View {
    
    @ObservedRealmObject var textNote: TextNoteVM
    @EnvironmentObject var navigation: Navigation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack(alignment: .top, spacing: 12) {
                
                AnimatedImage(url: textNote.userProfile?.avatarUrl)
                    .placeholder {
                        Color.secondary.opacity(0.2)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .imageScale(.large)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .background(
                        Color.secondary.opacity(0.2)
                    )
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    
                    HStack(spacing: 8) {
                        if let name = textNote.userProfile?.name, name.isValidName() {
                            Text("@"+name)
                                .font(.system(.subheadline, weight: .bold))
                        }
                        HStack(alignment: .top, spacing: 2) {
                            Image(systemName: "key.fill")
                                .imageScale(.small)
                            Text(textNote.publicKey.prefix(8))
                        }
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                    }

                    Text(textNote.createdAt, style: .relative)
                        .font(.system(.caption2, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(10)
            .onTapGesture {
                if let userProfile = textNote.userProfile {
                    self.navigation.homePath.append(Navigation.NavUserProfile(userProfile: userProfile))
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            if let content = textNote.contentFormatted {
                
//                VStack(spacing: 0) {
//
//                    Rectangle()
//                        .frame(height: 200)
//                    HStack {
//                        Image(systemName: "rectangle.and.hand.point.up.left.fill")
//                            .font(.body)
//                            .fontWeight(.regular)
//                        Text("Tap Image to watch video")
//                        //Spacer()
//                    }
//                    .font(.caption)
//                    .fontWeight(.bold)
//                    .padding(8)
//
//                }
//                .background(.secondary.opacity(0.3))
//                .cornerRadius(8)
                
                if let videoUrl = textNote.videoUrl {
                    
                    VStack(spacing: 0) {
                        AZVideoPlayer(player: AVPlayer(url: videoUrl))
                            .frame(height: 200)
                            .shadow(radius: 0)
                        HStack {
                            Image(systemName: "rectangle.and.hand.point.up.left.fill")
                                .font(.body)
                                .fontWeight(.regular)
                            Text("Tap Image to watch video")
                            //Spacer()
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(8)
                    }
                    .background(.secondary.opacity(0.3))
                    .cornerRadius(8)
                    
                } else if let imageUrl = textNote.imageUrl {
                    VStack {
                        AnimatedImage(url: imageUrl)
                            .placeholder {
                                Color.secondary.opacity(0.2)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .imageScale(.large)
                                            .scaleEffect(3.0)
                                    )
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaledToFit()
                            .cornerRadius(8)
                    }
                }
                                
                Text(content)
                    .font(.body)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 32) {
                Image(systemName: "bubble.left")
                Image(systemName: "heart")
                Image(systemName: "square.and.arrow.up")
            }
            .imageScale(.small)
            .foregroundColor(.secondary)
            
        }

    }
}

struct NewPostsToastView: View {
    
    let avatarUrls: [URL]
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.up")
            
            HStack(spacing: -8) {
                
                ForEach(avatarUrls, id: \.self.absoluteString) { url in
                    WebImage(url: url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 25, height: 25)
                        .cornerRadius(12.5)
                }

            }
            Text("Posted")
        }
        .font(.subheadline.bold())
        .foregroundColor(.white)
        .padding(.horizontal,  12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .foregroundColor(.accentColor)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 3)
        .offset(x: 0, y: 16)
    }
}
