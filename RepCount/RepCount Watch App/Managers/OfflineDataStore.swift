//
//  OfflineDataStore.swift
//  BenchCoach Watch App
//
//  オフラインCSVデータの保存・管理・アップロード
//

import Foundation

/// 保存済みCSVファイルの情報
struct SavedCSVFile: Identifiable {
    let id = UUID()
    let filename: String
    let url: URL
    let date: Date
    let fileSize: Int64
    var isUploaded: Bool
}

class OfflineDataStore: ObservableObject {
    
    // MARK: - Published
    
    @Published var savedFiles: [SavedCSVFile] = []
    @Published var isUploading = false
    @Published var uploadProgress: String = ""
    
    // MARK: - Configuration
    
    /// CSVアップロード先サーバーURL
    let serverURL: String = "https://repcount-monitor-ppcng5xypa-an.a.run.app"
    
    /// 自動削除の閾値（1日 = 86400秒）
    private let autoDeleteAge: TimeInterval = 86400
    
    // MARK: - File I/O Queue
    
    private let ioQueue = DispatchQueue(label: "com.repcount.offlineio", qos: .utility)
    
    // MARK: - CSV Writing State
    
    private var currentFileHandle: FileHandle?
    private var currentFileURL: URL?
    private var sampleCount: Int = 0
    
    // MARK: - CSV Header
    
    private let csvHeader = "timestamp,accX,accY,accZ,filteredAccY,phase,repCount\n"
    
    // MARK: - Directories
    
    /// センサーデータ保存ディレクトリ
    private var sensorDataDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("SensorData", isDirectory: true)
    }
    
    /// アップロード済みファイルの記録キー
    private let uploadedFilesKey = "com.repcount.uploadedFiles"
    
    // MARK: - Initialization
    
    init() {
        ensureDirectoryExists()
        autoDeleteOldFiles()
        refreshFileList()
    }
    
    // MARK: - Session Lifecycle
    
    /// セッション開始：新しいCSVファイルを作成
    func startSession() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.ensureDirectoryExists()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "sensor_\(formatter.string(from: Date())).csv"
            let fileURL = self.sensorDataDirectory.appendingPathComponent(filename)
            
            // ファイル作成
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            
            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                print("[OfflineDataStore] Failed to open file for writing: \(fileURL.path)")
                return
            }
            
            // ヘッダー書き込み
            if let headerData = self.csvHeader.data(using: .utf8) {
                handle.write(headerData)
            }
            
            self.currentFileHandle = handle
            self.currentFileURL = fileURL
            self.sampleCount = 0
            
            print("[OfflineDataStore] Started session: \(filename)")
        }
    }
    
    /// 複数行の文字列（チャンク）をまとめてCSVに追記
    func writeChunk(_ chunk: String) {
        if let data = chunk.data(using: .utf8) {
            ioQueue.async { [weak self] in
                guard let self = self else { return }
                guard let handle = self.currentFileHandle else { return }
                handle.write(data)
                // おおよそのサンプル数を\nの数から加算する（簡易的）
                let linesCount = chunk.filter { $0 == "\n" }.count
                self.sampleCount += linesCount
            }
        }
    }
    
    /// セッション終了：ファイルをクローズ
    func endSession() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let handle = self.currentFileHandle else { return }
            
            try? handle.synchronize()
            try? handle.close()
            
            self.currentFileHandle = nil
            
            if let url = self.currentFileURL {
                print("[OfflineDataStore] Ended session: \(url.lastPathComponent), \(self.sampleCount) samples written")
            }
            self.currentFileURL = nil
            self.sampleCount = 0
            
            // ファイルリストを更新
            DispatchQueue.main.async {
                self.refreshFileList()
            }
        }
    }
    
    // MARK: - File Management
    
    /// ファイル一覧を更新
    func refreshFileList() {
        let fm = FileManager.default
        let uploadedSet = getUploadedFileSet()
        
        guard let files = try? fm.contentsOfDirectory(at: sensorDataDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            DispatchQueue.main.async {
                self.savedFiles = []
            }
            return
        }
        
        let csvFiles = files
            .filter { $0.pathExtension == "csv" }
            .compactMap { url -> SavedCSVFile? in
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let size = (attrs?[.size] as? Int64) ?? 0
                let date = (attrs?[.creationDate] as? Date) ?? Date()
                let isUploaded = uploadedSet.contains(url.lastPathComponent)
                return SavedCSVFile(filename: url.lastPathComponent, url: url, date: date, fileSize: size, isUploaded: isUploaded)
            }
            .sorted { $0.date > $1.date }
        
        DispatchQueue.main.async {
            self.savedFiles = csvFiles
        }
    }
    
    /// 1日以上前のファイルを自動削除
    func autoDeleteOldFiles() {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-autoDeleteAge)
        
        guard let files = try? fm.contentsOfDirectory(at: sensorDataDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for file in files where file.pathExtension == "csv" {
            let attrs = try? fm.attributesOfItem(atPath: file.path)
            if let created = attrs?[.creationDate] as? Date, created < cutoff {
                try? fm.removeItem(at: file)
                print("[OfflineDataStore] Auto-deleted old file: \(file.lastPathComponent)")
            }
        }
    }
    
    /// ファイルを削除
    func deleteFile(_ file: SavedCSVFile) {
        try? FileManager.default.removeItem(at: file.url)
        removeFromUploadedSet(file.filename)
        refreshFileList()
    }
    
    /// 全ファイルを削除
    func deleteAllFiles() {
        for file in savedFiles {
            try? FileManager.default.removeItem(at: file.url)
        }
        UserDefaults.standard.removeObject(forKey: uploadedFilesKey)
        refreshFileList()
    }
    
    // MARK: - Upload
    
    /// 単一ファイルをサーバーへアップロード（ファイルストリームでのRawアップロード）
    func uploadFile(_ file: SavedCSVFile, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/upload-csv") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        
        // ファイル名をヘッダーで送信（URLエンコード）
        let encodedFilename = file.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.filename
        request.setValue(encodedFilename, forHTTPHeaderField: "X-File-Name")
        request.timeoutInterval = 60 // 大きめなファイルも送れるよう長めに
        
        // uploadTask(fromFile:) を使うことでメモリ枯渇を防ぐ
        let task = URLSession.shared.uploadTask(with: request, fromFile: file.url) { [weak self] _, response, error in
            if let error = error {
                print("[OfflineDataStore] Upload failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                self?.markAsUploaded(file.filename)
                DispatchQueue.main.async {
                    self?.refreshFileList()
                    completion(true)
                }
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[OfflineDataStore] Upload failed with status: \(status)")
                DispatchQueue.main.async { completion(false) }
            }
        }
        task.resume()
    }
    
    /// 未アップロードファイルを一括送信
    func uploadAllPending() {
        let pendingFiles = savedFiles.filter { !$0.isUploaded }
        guard !pendingFiles.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isUploading = true
            self.uploadProgress = "0/\(pendingFiles.count)"
        }
        
        var completed = 0
        let total = pendingFiles.count
        
        for file in pendingFiles {
            uploadFile(file) { [weak self] _ in
                completed += 1
                DispatchQueue.main.async {
                    self?.uploadProgress = "\(completed)/\(total)"
                    if completed == total {
                        self?.isUploading = false
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: sensorDataDirectory.path) {
            try? fm.createDirectory(at: sensorDataDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func getUploadedFileSet() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: uploadedFilesKey) ?? []
        return Set(array)
    }
    
    private func markAsUploaded(_ filename: String) {
        var set = getUploadedFileSet()
        set.insert(filename)
        UserDefaults.standard.set(Array(set), forKey: uploadedFilesKey)
    }
    
    private func removeFromUploadedSet(_ filename: String) {
        var set = getUploadedFileSet()
        set.remove(filename)
        UserDefaults.standard.set(Array(set), forKey: uploadedFilesKey)
    }
}
