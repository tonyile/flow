import SwiftUI

struct EditFlowView: View {
    @StateObject private var flowStore = FlowStore.shared
    @Environment(\.dismiss) private var dismiss
    
    let flowItem: FlowItem
    
    @State private var title = ""
    @State private var selectedType: FlowType = .event
    @State private var amount: Double = 0
    @State private var currency = "¥"
    @State private var selectedDate = Date()
    @State private var notes = ""
    @State private var location = ""
    
    // 相关数据
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
    @State private var showingDeleteAlert = false
    
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
                
                // 删除按钮
                Section {
                    Button("删除此流水记录") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("编辑流水")
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
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("删除", role: .destructive) {
                    flowStore.deleteItem(flowItem)
                    dismiss()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确定要删除这条流水记录吗？此操作无法撤销。")
            }
        }
        .onAppear {
            loadFlowItemData()
        }
    }
    
    private func loadFlowItemData() {
        title = flowItem.title
        selectedType = flowItem.type
        amount = flowItem.amount ?? 0
        currency = flowItem.currency
        selectedDate = flowItem.date
        notes = flowItem.notes
        location = flowItem.location ?? ""
        relatedPeople = flowItem.relatedPeople
        relatedItems = flowItem.relatedItems
        tags = flowItem.tags
    }
    
    private func saveFlowItem() {
        // 验证输入
        guard !title.isEmpty else {
            validationMessage = "请输入标题"
            showingValidationAlert = true
            return
        }
        
        if selectedType.hasAmount && amount < 0 {
            validationMessage = "金额不能为负数"
            showingValidationAlert = true
            return
        }
        
        // 更新流水项目
        flowItem.title = title
        flowItem.type = selectedType
        flowItem.amount = selectedType.hasAmount ? amount : nil
        flowItem.currency = currency
        flowItem.relatedPeople = relatedPeople
        flowItem.relatedItems = relatedItems
        flowItem.date = selectedDate
        flowItem.notes = notes
        flowItem.tags = tags
        flowItem.location = location.isEmpty ? nil : location
        
        // 保存到存储
        flowStore.updateFlowItem(flowItem)
        
        // 关闭视图
        dismiss()
    }
    
    // MARK: - Computed Properties
    private var typePickerView: some View {
        Picker("类型", selection: $selectedType) {
            ForEach(FlowType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
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
}

#Preview {
    let sampleItem = FlowItem(
        title: "示例流水",
        type: .event,
        amount: 100.0,
        currency: "¥",
        relatedPeople: ["张三"],
        relatedItems: ["礼品"],
        date: Date(),
        notes: "示例备注",
        tags: ["重要"],
        location: "北京",
        isCompleted: false
    )
    
    return EditFlowView(flowItem: sampleItem)
}