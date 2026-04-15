//
//  SavedDataView.swift
//  BenchCoach Watch App
//
//  オフライン保存されたセンサーデータの管理とアップロード
//

import SwiftUI

struct SavedDataView: View {
    @StateObject private var offlineStore = OfflineDataStore()
    
    var body: some View {
        List {
            Section(header: Text("保存データ (\(offlineStore.savedFiles.count))")) {
                ForEach(offlineStore.savedFiles) { file in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.filename)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        HStack {
                            Text(file.date, style: .time)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(file.isUploaded ? "送信済み" : "未送信")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(file.isUploaded ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(file.isUploaded ? .green : .orange)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 2)
                    .swipeActions {
                        Button(role: .destructive) {
                            offlineStore.deleteFile(file)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            
            if !offlineStore.savedFiles.isEmpty {
                Section {
                    Button(action: {
                        offlineStore.uploadAllPending()
                    }) {
                        HStack {
                            Spacer()
                            if offlineStore.isUploading {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("送信中... (\(offlineStore.uploadProgress))")
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("未送信データを送信")
                            }
                            Spacer()
                        }
                        .foregroundColor(offlineStore.isUploading ? .gray : .blue)
                    }
                    .disabled(offlineStore.isUploading)
                    
                    Button(role: .destructive, action: {
                        offlineStore.deleteAllFiles()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                            Text("すべてのデータを削除")
                            Spacer()
                        }
                    }
                    .disabled(offlineStore.isUploading)
                }
            } else {
                Text("保存されたデータはありません")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("データ送信")
        .onAppear {
            offlineStore.refreshFileList()
        }
    }
}

#Preview {
    SavedDataView()
}
