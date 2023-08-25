//
//  PrinterViewModel.swift
//  MiniPrinter
//
//  Created by 潘新宇 on 2023/8/15.
//

import SwiftUI
import Combine

class PrinterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var uiImage: UIImage? {
        didSet {
            toolBarViewModel.uiImage = uiImage
            printImage = nil
            toolBarViewModel.previewImage = nil
            toolBarViewModel.isPreview = false
        }
    }
    @Published var showLoading: Bool = false
    @Published var orImage: UIImage?
    @Published var printImage: UIImage?
    @Published var infoModel = PrinterInfoModel.errorModel
    @Published var toolBarViewModel = PrintToolBarViewModel()
    @Published var isPreview: Bool = false

    // MARK: - Private Properties
    private var manager = BTSearchManager.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        self.toolBarViewModel.imagePreviewCallback = { [weak self] image in
            self?.uiImage = image
            self?.printImage = image
        }
        self.toolBarViewModel.imagePrintCallback = { [weak self] isOneTimePrint in
            self?.processAndSendImageForPrinting(self?.uiImage, isOneTimePrint: isOneTimePrint)
        }
        toolBarViewModel.$isPreview
            .sink { [weak self] value in
                self?.isPreview = value
            }
            .store(in: &cancellables)
        setupBluetoothDataBinding()
    }
    
    // MARK: - Private Methods
    
    private func setupBluetoothDataBinding() {
        manager.dataSubject
            .compactMap { $0 }
            .compactMap { try? PrinterInfoModel(data: $0) }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] newModel in
                self?.infoModel = newModel
            })
            .store(in: &cancellables)
    }

    private func processAndSendImageForPrinting(_ image: UIImage?, isOneTimePrint: Bool) {
        if let image = image {
            var datas = ImageHelper.generateBinaryDataArray(from: image)!
            let startPrinterCommand: [UInt8] = [0xA6, 0xA6, 0xA6, 0xA6, 0x01]
            let startPrinterData = Data(startPrinterCommand)
            datas.append(startPrinterData)
            if isOneTimePrint {
                self.showLoading = true
                BTSearchManager.default.sendDatas(datas) {
                    self.showLoading = false;
                }
            } else {
                self.showLoading = true
                BTSearchManager.default.sendDatasWithoutResponse(datas) {
                    self.showLoading = false;
                }
            }
        }
    }
}

// MARK: - Bluetooth Handling
extension PrinterViewModel {
    private func sendDatas(_ datas: [Data]) {
        print("send count: \(datas.count)")
        self.showLoading = true
        BTSearchManager.default.sendDatasWithoutResponse(datas) {
            self.showLoading = false;
        }
    }
}

