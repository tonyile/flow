import SwiftUI

struct AddFlowView: View {
    @StateObject private var flowStore = FlowStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var selectedType: FlowType = .event
    @State private var amount: Double = 0
    @State private var currency = "¥"
    @State private var selectedDate = Date()
    @State private var notes = ""
    @State private var location = ""
    
    // 相关信息
    @State private var relatedPeople: [String] = []
    @State private var relatedItems: [String] = []
    @State private var tags: [String] = []
    
    // 输入状态
    @State private var newPersonName = ""
    @State private var newItemName = ""
    @State private var newTagName = ""
    @State private var showingPersonInput = false
    @State private var showingItemInput = false
    @State private var showingTagInput = false
    
    // 验证状态
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // 基本信息
                Section("基本信息") {
                    TextField("标题", text: $title)
                    
                    typePickerView
                    
                    DatePicker("日期时间", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    if selectedType.hasAmount {
                        amountInputView
                    }
                }
                
                // 相关人员
                Section("相关人员") {
                    ForEach(relatedPeople, id: \.self) { person in
                        HStack {
                            Text(person)
                            Spacer()
                            Button("删除") {
                                relatedPeople.removeAll { $0 == person }
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    Button("添加人员") {
                        showingPersonInput = true
                    }
                    .foregroundColor(.blue)
                }
                
                // 相关物品
                Section("相关物品") {
                    ForEach(relatedItems, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button("删除") {
                                relatedItems.removeAll { $0 == item }
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    Button("添加物品") {
                        showingItemInput = true
                    }
                    .foregroundColor(.blue)
                }
                
                // 标签
                Section("标签") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Button("添加标签") {
                        showingTagInput = true
                    }
                    .foregroundColor(.blue)
                }
                
                // 其他信息
                Section("其他信息") {
                    TextField("地点", text: $location)
                    
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加流水")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveFlowItem()
                    }
                    .disabled(title.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveFlowItem()
                    }
                    .disabled(title.isEmpty)
                }
                #endif
            }
            .alert("添加人员", isPresented: $showingPersonInput) {
                TextField("姓名", text: $newPersonName)
                Button("添加") {
                    if !newPersonName.isEmpty && !relatedPeople.contains(newPersonName) {
                        relatedPeople.append(newPersonName)
                        newPersonName = ""
                    }
                }
                Button("取消", role: .cancel) {
                    newPersonName = ""
                }
            }
            .alert("添加物品", isPresented: $showingItemInput) {
                TextField("物品名称", text: $newItemName)
                Button("添加") {
                    if !newItemName.isEmpty && !relatedItems.contains(newItemName) {
                        relatedItems.append(newItemName)
                        newItemName = ""
                    }
                }
                Button("取消", role: .cancel) {
                    newItemName = ""
                }
            }
            .alert("添加标签", isPresented: $showingTagInput) {
                TextField("标签名称", text: $newTagName)
                Button("添加") {
                    if !newTagName.isEmpty && !tags.contains(newTagName) {
                        tags.append(newTagName)
                        newTagName = ""
                    }
                }
                Button("取消", role: .cancel) {
                    newTagName = ""
                }
            }
            .alert("验证失败", isPresented: $showingValidationAlert) {
                Button("确定") { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    // MARK: - Helper Views
    private var typePickerView: some View {
        Picker("类型", selection: $selectedType) {
            ForEach(FlowType.allCases, id: \.self) { type in
                Text(type.displayName)
                    .tag(type)
            }
        }
    }
    
    private var amountInputView: some View {
        HStack {
            TextField("金额", value: $amount, format: .number)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            
            Picker("货币", selection: $currency) {
                Text("¥").tag("¥")
                Text("$").tag("$")
                Text("€").tag("€")
                Text("£").tag("£")
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private func saveFlowItem() {
        // 验证输入
        guard !title.isEmpty else {
            validationMessage = "请输入标题"
            showingValidationAlert = true
            return
        }
        
        // 创建流水项
        let flowItem = FlowItem()
        flowItem.title = title
        flowItem.type = selectedType
        flowItem.amount = selectedType.hasAmount ? amount : nil
        flowItem.currency = selectedType.hasAmount ? currency : "¥"
        flowItem.date = selectedDate
        flowItem.notes = notes.isEmpty ? "" : notes
        flowItem.location = location.isEmpty ? nil : location
        flowItem.relatedPeople = relatedPeople
        flowItem.relatedItems = relatedItems
        flowItem.tags = tags
        
        // 保存到存储
        flowStore.addFlowItem(flowItem)
        
        // 关闭视图
        dismiss()
    }
}

#Preview {
    AddFlowView()
}