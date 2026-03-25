//
//  RepCount_Watch_AppTests.swift
//  RepCount Watch AppTests
//

import XCTest
@testable import RepCount_Watch_App

final class RepCount_Watch_AppTests: XCTestCase {

    var repDetector: RepDetector!

    override func setUpWithError() throws {
        // テストごとに新品のRepDetectorを用意する
        repDetector = RepDetector()
    }

    override func tearDownWithError() throws {
        repDetector = nil
    }

    /// ユーザー保存の実録CSVデータを全て流し込み、正しいレップ数を精度よくカウントできるかを検証します
    func testRepDetectionAccuracy() throws {
        
        // ==============================================================
        // 🧪 テストケースの登録
        // ==============================================================
        // 追加したCSVファイル名（".csv"無し）と、期待する正解レップ数を登録します。
        // 例: repcount_sensor_10_reps_80kg.csv を入れたなら、第一引数にファイル名、第二引数に10を入れます。
        let testCases: [(fileName: String, expectedReps: Int)] = [
            ("bench_20kg_10reps",  10),
            ("bench_60kg_set1_10reps",10),
            ("bench_60kg_set2_10reps",10),
            ("bench_80kg_7reps",  7),
            // ("repcount_sensor_test2", 10)
        ]
        
        let bundle = Bundle(for: type(of: self))
        
        if testCases.isEmpty {
            print("⚠️ テスト対象のCSVが登録されていません。XCTAssert をスキップします。")
            return
        }
        
        // 登録されたテストケースごとにループで検証
        for testCase in testCases {
            // そもそもXcodeのテストバンドルにファイルが含まれているか確認
            guard bundle.url(forResource: testCase.fileName, withExtension: "csv") != nil else {
                XCTFail("❌ CSVファイルが見つかりません。テストターゲットの『Copy Bundle Resources』に \(testCase.fileName).csv が追加されているか確認してください。")
                continue
            }
            
            // CSVロード
            let rows = CSVLoader.load(fromResource: testCase.fileName, bundle: bundle)
            XCTAssertFalse(rows.isEmpty, "Failed to load row data from \(testCase.fileName).csv")
            
            // リセット (setUpで呼ばれているが念の為)
            repDetector.reset()
            
            // CSVの生データを流し込む（実機の 50Hz ストリーミングを高速エミュレート）
            for row in rows {
                repDetector.processAcceleration(accX: row.accX, accY: row.accY, accZ: row.accZ)
            }
            
            // テスト検証！！
            XCTAssertEqual(
                repDetector.repCount,
                testCase.expectedReps,
                "⚠️ [Rep Error] Failed on '\(testCase.fileName).csv'. Expected \(testCase.expectedReps) reps, but Detector counted \(repDetector.repCount)."
            )
            
            print("🎯 Success: '\(testCase.fileName).csv' properly detected \(testCase.expectedReps) reps.")
        }
    }
}
