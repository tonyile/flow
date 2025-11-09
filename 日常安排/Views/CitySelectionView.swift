import SwiftUI
import CoreLocation

struct CitySelectionView: View {
    @Binding var selectedCity: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var weatherManager = WeatherManager.shared
    
    @State private var searchText = ""
    @State private var isUsingCurrentLocation = true
    @State private var isLoadingLocation = false // 添加获取位置状态
    
    // 常用城市列表 - 扩展更多中国城市
    private let popularCities = [
        // 直辖市
        "北京", "上海", "天津", "重庆",
        
        // 省会城市
        "广州", "深圳", "杭州", "南京", "成都", "武汉", "西安", "郑州", 
        "济南", "哈尔滨", "沈阳", "长春", "石家庄", "太原", "呼和浩特",
        "银川", "西宁", "兰州", "乌鲁木齐", "拉萨", "昆明", "贵阳", "南宁",
        "海口", "福州", "南昌", "合肥", "长沙",
        
        // 重要地级市
        "苏州", "无锡", "常州", "扬州", "南通", "徐州", "盐城", "淮安", "连云港", "泰州", "宿迁", "镇江",
        "宁波", "温州", "嘉兴", "湖州", "绍兴", "金华", "衢州", "舟山", "台州", "丽水",
        "青岛", "烟台", "潍坊", "临沂", "淄博", "济宁", "泰安", "威海", "日照", "滨州",
        "大连", "鞍山", "抚顺", "本溪", "丹东", "锦州", "营口", "阜新", "辽阳", "盘锦",
        "吉林", "四平", "辽源", "通化", "白山", "松原", "白城", "延边",
        "齐齐哈尔", "鸡西", "鹤岗", "双鸭山", "大庆", "伊春", "佳木斯", "七台河", "牡丹江", "黑河",
        "唐山", "秦皇岛", "邯郸", "邢台", "保定", "张家口", "承德", "沧州", "廊坊", "衡水",
        "厦门", "莆田", "三明", "泉州", "漳州", "南平", "龙岩", "宁德",
        "景德镇", "萍乡", "九江", "新余", "鹰潭", "赣州", "吉安", "宜春", "抚州", "上饶",
        "芜湖", "蚌埠", "淮南", "马鞍山", "淮北", "铜陵", "安庆", "黄山", "滁州", "阜阳",
        "宿州", "六安", "亳州", "池州", "宣城",
        "洛阳", "开封", "平顶山", "安阳", "鹤壁", "新乡", "焦作", "濮阳", "许昌", "漯河",
        "三门峡", "南阳", "商丘", "信阳", "周口", "驻马店",
        "株洲", "湘潭", "衡阳", "邵阳", "岳阳", "常德", "张家界", "益阳", "郴州", "永州",
        "怀化", "娄底", "湘西",
        "韶关", "珠海", "汕头", "佛山", "江门", "湛江", "茂名", "肇庆", "惠州", "梅州",
        "汕尾", "河源", "阳江", "清远", "东莞", "中山", "潮州", "揭阳", "云浮",
        "柳州", "桂林", "梧州", "北海", "防城港", "钦州", "贵港", "玉林", "百色", "贺州",
        "河池", "来宾", "崇左",
        "三亚", "儋州", "五指山", "琼海", "文昌", "万宁", "东方", "定安", "屯昌", "澄迈",
        "临高", "白沙", "昌江", "乐东", "陵水", "保亭", "琼中",
        "自贡", "攀枝花", "泸州", "德阳", "绵阳", "广元", "遂宁", "内江", "乐山", "南充",
        "眉山", "宜宾", "广安", "达州", "雅安", "巴中", "资阳", "阿坝", "甘孜", "凉山",
        "六盘水", "遵义", "安顺", "毕节", "铜仁", "黔西南", "黔东南", "黔南",
        "曲靖", "玉溪", "保山", "昭通", "丽江", "普洱", "临沧", "楚雄", "红河", "文山",
        "西双版纳", "大理", "德宏", "怒江", "迪庆",
        "宝鸡", "咸阳", "铜川", "渭南", "延安", "榆林", "汉中", "安康", "商洛"
    ]
    
    var filteredCities: [String] {
        if searchText.isEmpty {
            return popularCities
        } else {
            return popularCities.filter { $0.contains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 搜索框
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                List {
                    // 当前位置选项
                    Section {
                        Button(action: {
                            selectCurrentLocation()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text("当前位置")
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                if isLoadingLocation {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if selectedCity == "当前位置" || (weatherManager.currentCityName != nil && selectedCity == weatherManager.currentCityName) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(isLoadingLocation)
                    }
                    
                    // 城市列表
                    Section(header: Text("选择城市")) {
                        ForEach(filteredCities, id: \.self) { city in
                            Button(action: {
                                selectedCity = city
                                isUsingCurrentLocation = false
                                dismiss()
                            }) {
                                HStack {
                                    Text(city)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCity == city {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择城市")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
    
    // 选择当前位置并获取城市名称
    private func selectCurrentLocation() {
        isLoadingLocation = true
        Task {
            let cityName = await weatherManager.forceRequestLocationAndGetCity()
            
            DispatchQueue.main.async {
                self.isLoadingLocation = false
                if let cityName = cityName, !cityName.contains("失败") && !cityName.contains("超时") && !cityName.contains("异常") && !cityName.contains("拒绝") {
                    self.selectedCity = cityName
                } else {
                    // 如果定位失败，仍然选择"当前位置"，但显示错误信息
                    self.selectedCity = "当前位置"
                    // 定位失败
                }
                dismiss()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索城市", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    CitySelectionView(selectedCity: .constant("当前位置"))
}