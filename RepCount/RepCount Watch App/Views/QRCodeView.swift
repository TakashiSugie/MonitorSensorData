//
//  QRCodeView.swift
//  RepCount Watch App
//
//  ダッシュボードURLをQRコードとして表示し、iPhoneでスキャン可能にする
//

import SwiftUI

struct QRCodeView: View {
    let url: String
    @Environment(\.dismiss) var dismiss
    
    // QRコード生成API (api.qrserver.com など)
    private var qrURL: URL? {
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=\(encodedUrl)")
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Scan with iPhone")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
            
            if let targetURL = qrURL {
                AsyncImage(url: targetURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .background(Color.white)
                            .padding(4)
                            .cornerRadius(8)
                    case .failure:
                        VStack {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.title2)
                            Text("Retry later")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 128, height: 128)
            }
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.gray)
        }
        .padding()
    }
}

#Preview {
    QRCodeView(url: "https://google.com")
}
