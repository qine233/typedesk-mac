import SwiftUI

// MARK: - 通用小件

private struct StatCard: View {
    let title: String
    var tint: Color = Theme.accent
    var content: () -> AnyView

    init(_ title: String, tint: Color = Theme.accent, @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.tint = tint
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.textLight)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .inkCard()
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textStrong)
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textLight)
                }
                Spacer()
            }
            content()
        }
        .padding(16)
        .inkCard()
    }
}

private func moneyColor(_ v: Double) -> Color { v > 0 ? Theme.danger : v < 0 ? Theme.statusPublish : Theme.textLight }

private struct InlineActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(hover ? Theme.accentHover : Theme.accent)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}

private struct KeyMissing: View {
    var body: some View {
        VStack(spacing: 0) {
            EmptyStateView(title: "还没配置站点密钥",
                           subtitle: "Typecho 后台 → NolineApi 插件设置\n把密钥填入 NLtypedesk 设置 → 站点数据密钥")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

extension BillMonth: Identifiable { var id: String { month } }
extension BillKindShare: Identifiable { var id: String { kind } }

// MARK: - 健康：中栏列表

struct HealthMiddleListView: View {
    @EnvironmentObject var state: AppState
    @State private var editingRecord: HealthRecord?
    @State private var addingNew = false

    private var records: [HealthRecord] { (state.healthData?.series ?? []).reversed() }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader("健康记录") {
                Button { addingNew = true } label: { panePlus("记体重") }
            }
            if state.siteKey.isEmpty {
                EmptyStateView(title: "未配置站点密钥", subtitle: "设置里填入密钥后即可记录体重")
            } else if records.isEmpty && !state.siteDataLoading {
                EmptyStateView(title: "还没有体重记录",
                               subtitle: "点上方「记体重」开始\n一天一条，同日会覆盖")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(records) { record in
                            HealthRow(record: record)
                                .onTapGesture { editingRecord = record }
                                .contextMenu {
                                    Button("删除这天", role: .destructive) {
                                        Task { await state.deleteHealthRecord(date: record.date) }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 14)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        .onAppear { autoLoad() }
        .sheet(item: $editingRecord) { HealthEditSheet(existing: $0) }
        .sheet(isPresented: $addingNew) { HealthEditSheet(existing: nil) }
    }

    private func autoLoad() {
        guard state.healthData == nil, !state.siteKey.isEmpty, !state.siteDataLoading else { return }
        Task { await state.refreshSiteData() }
    }

    private func panePlus(_ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.accent).foregroundColor(.white)
        .clipShape(Capsule())
    }
}

private struct HealthRow: View {
    let record: HealthRecord
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.date).font(.system(size: 11)).foregroundColor(Theme.textLight)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(NLFormat.weight(record.weight))
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.textStrong)
                    Text("kg").font(.system(size: 10)).foregroundColor(Theme.textLight)
                    if let d = record.delta {
                        Text(NLFormat.signedWeight(d))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(d > 0 ? Theme.danger : d < 0 ? Theme.statusPublish : Theme.textLight)
                    }
                }
                HStack(spacing: 6) {
                    if let bmi = record.bmi {
                        Text("BMI \(NLFormat.weight(bmi)) · \(NLFormat.bmiCategory(record.category))")
                            .font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    }
                    if let fat = record.fat {
                        Text("体脂 \(NLFormat.weight(fat))%")
                            .font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    }
                }
                if let note = record.note, !note.isEmpty {
                    Text(note).font(.system(size: 11)).foregroundColor(Theme.textLight).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .inkCard(hover: hover)
        .onHover { hover = $0 }
    }
}

// MARK: - 健康：录入/编辑 sheet

struct HealthEditSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let existing: HealthRecord?

    @State private var date = ""
    @State private var weight = ""
    @State private var fat = ""
    @State private var note = ""
    @State private var submitting = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(existing == nil ? "记体重" : "修改 \(date) 的记录")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(Theme.textLight) }
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            if existing != nil {
                Text("修改会整体覆盖这一天的记录，体重、体脂、备注都已带回。")
                    .font(.system(size: 11)).foregroundColor(Theme.textLight)
                    .padding(.bottom, 10)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    fieldLabel("日期")
                    if existing != nil {
                        Text(date).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                    } else {
                        TextField("YYYY-MM-DD", text: $date)
                            .textFieldStyle(.roundedBorder).frame(width: 150)
                    }
                }
                GridRow {
                    fieldLabel("体重 kg")
                    TextField("20 – 400", text: $weight)
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                }
                GridRow {
                    fieldLabel("体脂 %（可选）")
                    TextField("1 – 70", text: $fat)
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                }
                GridRow {
                    fieldLabel("备注（可选）")
                    TextField("最多 200 字", text: $note)
                        .textFieldStyle(.roundedBorder).frame(width: 260)
                }
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundColor(Theme.danger).padding(.top, 10)
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("取消").font(.system(size: 12))
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textMain)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)

                Button { Task { await submit() } } label: {
                    if submitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("保存").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(submitting)
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(width: 400)
        .background(Theme.card)
        .onAppear {
            date = existing?.date ?? state.serverToday
            weight = existing.map { NLFormat.weight($0.weight) } ?? ""
            fat = existing?.fat.map { NLFormat.weight($0) } ?? ""
            note = existing?.note ?? ""
        }
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
    }

    private func submit() async {
        error = nil
        guard let w = Double(weight) else { error = "体重要填数字"; return }
        guard (20...400).contains(w) else { error = "体重要在 20 – 400 kg 之间"; return }
        var fatValue: Double?
        if !fat.isEmpty {
            guard let f = Double(fat) else { error = "体脂要填数字"; return }
            guard (1...70).contains(f) else { error = "体脂要在 1 – 70 之间"; return }
            fatValue = f
        }
        guard NLDate.isValid(date) else { error = "日期格式要是 YYYY-MM-DD"; return }
        submitting = true
        defer { submitting = false }
        do {
            try await state.saveHealthRecord(date: date, weight: (w * 10).rounded() / 10,
                                             fat: fatValue, note: note)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - 健康：右栏看板

struct HealthDetailView: View {
    @EnvironmentObject var state: AppState
    @State private var showEditor = false

    var body: some View {
        Group {
            if state.siteKey.isEmpty {
                KeyMissing()
            } else if let h = state.healthData {
                content(h)
            } else if state.siteDataLoading {
                VStack { ProgressView(); Text("正在读取站点数据…").font(.system(size: 11)).foregroundColor(Theme.textLight) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            } else {
                VStack(spacing: 12) {
                    EmptyStateView(title: "读不到站点数据",
                                   subtitle: state.siteDataError ?? "点下面的按钮重试")
                    Button { Task { await state.refreshSiteData() } } label: {
                        Text("重试").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showEditor) { HealthEditSheet(existing: nil) }
    }

    private func content(_ h: HealthData) -> some View {
        let latest = h.latest
        let series = h.series ?? []
        return ScrollView {
            VStack(spacing: 12) {
                HStack {
                    InlineActionButton(title: "记体重", icon: "plus") { showEditor = true }
                    Spacer()
                    Text("\(h.count ?? 0) 条记录").font(.system(size: 11)).foregroundColor(Theme.textLight)
                }
                HStack(spacing: 12) {
                    StatCard("当前体重") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(latest.map { NLFormat.weight($0.weight) + " kg" } ?? "—")
                                .font(.system(size: 22, weight: .bold)).foregroundColor(Theme.textStrong)
                            Text(latest?.date ?? "")
                                .font(.system(size: 10)).foregroundColor(Theme.textLight)
                        }
                    }
                    StatCard("BMI", tint: bmiColor(latest?.category)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(latest?.bmi.map { NLFormat.weight($0) } ?? "—")
                                .font(.system(size: 22, weight: .bold)).foregroundColor(Theme.textStrong)
                            Text(NLFormat.bmiCategory(latest?.category))
                                .font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    StatCard("目标", tint: h.goal.map { $0.done == true ? Theme.statusPublish : Theme.headingMarker } ?? Theme.info) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let g = h.goal, g.target != nil {
                                Text(g.done == true ? "已达成" : "还差 \(NLFormat.weight(g.remaining ?? 0)) kg")
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.textStrong)
                                Text("目标 \(NLFormat.weight(g.target ?? 0)) kg")
                                    .font(.system(size: 10)).foregroundColor(Theme.textLight)
                            } else {
                                Text("未设目标").font(.system(size: 14)).foregroundColor(Theme.textLight)
                            }
                        }
                    }
                }

                SectionCard("涨跌", subtitle: "相对窗口起点，按全序列计算") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let changes = h.changes, !changes.isEmpty {
                            ForEach(["d7", "d30", "d90"], id: \.self) { key in
                                if let c = changes[key] { changeRow(key, c) }
                            }
                        } else {
                            Text("记录还不够长，看不出涨跌").font(.system(size: 12)).foregroundColor(Theme.textLight)
                        }
                    }
                }

                SectionCard("趋势", subtitle: "\(h.count ?? 0) 条 · \(h.first ?? "") 起") {
                    WeightTrendChart(series: series)
                        .frame(height: 200)
                }

                if let s = h.stats {
                    SectionCard("区间统计") {
                        HStack(spacing: 0) {
                            statColumn("最轻", NLFormat.weight(s.min))
                            statColumn("最重", NLFormat.weight(s.max))
                            statColumn("平均", NLFormat.weight(s.avg))
                            if let ideal = h.profile?.ideal {
                                statColumn("理想区间", "\(NLFormat.weight(ideal.low)) – \(NLFormat.weight(ideal.high))")
                            }
                        }
                    }
                }

                if let n = latest?.note, !n.isEmpty {
                    SectionCard("最新备注") {
                        Text(n).font(.system(size: 12)).foregroundColor(Theme.textMain)
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.bg)
    }

    private func changeRow(_ key: String, _ c: HealthChange) -> some View {
        let spanText = key == "d7" ? "7 天" : key == "d30" ? "30 天" : "90 天"
        return HStack {
            Text(spanText).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.textMain)
                .frame(width: 48, alignment: .leading)
            if let d = c.delta {
                Text(NLFormat.signedWeight(d) + " kg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(d > 0 ? Theme.danger : d < 0 ? Theme.statusPublish : Theme.textLight)
            } else {
                Text("—").foregroundColor(Theme.textLight)
            }
            Spacer()
            if let from = c.from_date {
                Text("自 \(from)").font(.system(size: 10)).foregroundColor(Theme.textLight)
            }
        }
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textStrong)
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bmiColor(_ category: String?) -> Color {
        switch category {
        case "thin": return Theme.info
        case "normal": return Theme.statusPublish
        case "over": return Theme.statusDraft
        case "obese": return Theme.danger
        default: return Theme.accent
        }
    }
}

// MARK: - 趋势图（按真实日期定 x 轴）

struct WeightTrendChart: View {
    let series: [HealthRecord]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if series.isEmpty {
                    Text("暂无数据").font(.system(size: 12)).foregroundColor(Theme.textLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    gridAndLabels(in: geo.size)
                    if series.count == 1 {
                        Circle().fill(Theme.accent).frame(width: 8, height: 8)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    } else {
                        path(in: geo.size)
                    }
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let dates = series.compactMap { NLDate.date($0.date) }
        guard dates.count == series.count, let firstD = dates.first, let lastD = dates.last else { return [] }
        let weights = series.map { $0.weight }
        var lo = weights.min() ?? 0, hi = weights.max() ?? 1
        if hi - lo < 1 { let mid = (hi + lo) / 2; lo = mid - 0.5; hi = mid + 0.5 }
        let pad: CGFloat = 14
        let totalT = max(lastD.timeIntervalSince(firstD), 1)
        return zip(dates, weights).map { d, w in
            let x = pad + CGFloat(d.timeIntervalSince(firstD) / totalT) * (size.width - pad * 2)
            let y = pad + (1 - CGFloat((w - lo) / (hi - lo))) * (size.height - pad * 2)
            return CGPoint(x: x, y: y)
        }
    }

    private func path(in size: CGSize) -> some View {
        let pts = points(in: size)
        return ZStack {
            // 面积
            if let first = pts.first, let last = pts.last {
                Path { p in
                    p.move(to: CGPoint(x: first.x, y: size.height))
                    for pt in pts { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                Circle().fill(Theme.card).overlay(Circle().stroke(Theme.accent, lineWidth: 1.5))
                    .frame(width: 5, height: 5).position(pt)
            }
        }
    }

    private func gridAndLabels(in size: CGSize) -> some View {
        let dates = series.compactMap { NLDate.date($0.date) }
        return ZStack {
            ForEach(0..<4) { i in
                let y = 14 + CGFloat(i) / 3 * (size.height - 28)
                Path { p in
                    p.move(to: CGPoint(x: 14, y: y)); p.addLine(to: CGPoint(x: size.width - 14, y: y))
                }.stroke(Theme.borderSoft, lineWidth: 1)
            }
            if let f = dates.first, let l = dates.last {
                VStack { Spacer(); HStack {
                    Text(NLDate.shortMD(NLDate.string(f))).font(.system(size: 9)).foregroundColor(Theme.textLight)
                    Spacer()
                    Text(NLDate.shortMD(NLDate.string(l))).font(.system(size: 9)).foregroundColor(Theme.textLight)
                } }.padding(.horizontal, 8).frame(height: size.height, alignment: .bottom)
            }
        }
    }
}

// MARK: - 记账：中栏流水

struct BillsMiddleListView: View {
    @EnvironmentObject var state: AppState
    @State private var editingBill: Bill?
    @State private var addingNew = false

    private struct DayGroup: Identifiable {
        let date: String
        let amount: Double
        let items: [Bill]
        var id: String { date }
    }

    private var groups: [DayGroup] {
        Dictionary(grouping: state.billRecords, by: \.date)
            .map { DayGroup(date: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader("买菜流水") {
                Button { addingNew = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("记一笔").font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accent).foregroundColor(.white).clipShape(Capsule())
                }
            }
            if state.siteKey.isEmpty {
                EmptyStateView(title: "未配置站点密钥", subtitle: "设置里填入密钥后即可记账")
            } else if groups.isEmpty && !state.siteDataLoading {
                EmptyStateView(title: "还没有流水",
                               subtitle: "一天可以记好几笔\n每笔都是新增，不会互相覆盖")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(groups) { group in
                            VStack(spacing: 6) {
                                HStack {
                                    Text(group.date).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("¥" + NLFormat.money(group.amount))
                                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textMain)
                                }
                                .padding(.horizontal, 4)
                                ForEach(group.items) { bill in
                                    BillRow(bill: bill, kindLabel: kindLabel(bill.kind))
                                        .onTapGesture { editingBill = bill }
                                        .contextMenu {
                                            Button("删除这笔", role: .destructive) {
                                                Task { await state.deleteBill(id: bill.id) }
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.bottom, 14)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        .onAppear {
            guard state.billsData == nil, !state.siteKey.isEmpty, !state.siteDataLoading else { return }
            Task { await state.refreshSiteData() }
        }
        .sheet(item: $editingBill) { BillEditSheet(existing: $0) }
        .sheet(isPresented: $addingNew) { BillEditSheet(existing: nil) }
    }

    private func kindLabel(_ kind: String?) -> String {
        guard let kind else { return "" }
        return state.billsData?.kinds?.first { $0.kind == kind }?.label ?? kind
    }
}

private struct BillRow: View {
    let bill: Bill
    let kindLabel: String
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bill.title).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textStrong)
                        .lineLimit(1)
                    if !kindLabel.isEmpty {
                        Text(kindLabel).font(.system(size: 9))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.accentBg).foregroundColor(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
                if let shop = bill.shop, !shop.isEmpty {
                    Text(shop).font(.system(size: 10)).foregroundColor(Theme.textLight).lineLimit(1)
                }
            }
            Spacer()
            Text(NLFormat.money(bill.amount))
                .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(Theme.textMain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .inkCard(hover: hover)
        .onHover { hover = $0 }
    }
}

// MARK: - 记账：录入/编辑 sheet

struct BillEditSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let existing: Bill?

    @State private var date = ""
    @State private var title = ""
    @State private var amount = ""
    @State private var kind = "other"
    @State private var shop = ""
    @State private var note = ""
    @State private var submitting = false
    @State private var error: String?

    private var kinds: [BillKind] {
        state.billsData?.kinds ?? [
            BillKind(kind: "veg", label: "蔬菜"), BillKind(kind: "fruit", label: "水果"),
            BillKind(kind: "meat", label: "肉禽"), BillKind(kind: "fish", label: "水产"),
            BillKind(kind: "egg", label: "蛋奶"), BillKind(kind: "grain", label: "米面粮油"),
            BillKind(kind: "seasoning", label: "调料"), BillKind(kind: "other", label: "其他"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(existing == nil ? "记一笔" : "修改「\(existing?.title ?? "")」")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textStrong)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(Theme.textLight) }
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    label("日期")
                    DatePicker("", selection: Binding(
                        get: { NLDate.date(date) ?? Date() },
                        set: { date = NLDate.string($0) }
                    ), displayedComponents: .date)
                    .labelsHidden().frame(width: 150)
                }
                GridRow {
                    label("品名")
                    TextField("要 ≤60 字", text: $title)
                        .textFieldStyle(.roundedBorder).frame(width: 260)
                }
                GridRow {
                    label("金额 元")
                    TextField("0.01 – 100000", text: $amount)
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                }
                GridRow {
                    label("分类")
                    Menu {
                        ForEach(kinds) { k in
                            Button(k.label) { kind = k.kind }
                        }
                    } label: {
                        HStack {
                            Text(kinds.first { $0.kind == kind }?.label ?? kind)
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textMain)
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                GridRow {
                    label("在哪儿买的")
                    TextField("≤40 字（可空）", text: $shop)
                        .textFieldStyle(.roundedBorder).frame(width: 260)
                }
                GridRow {
                    label("备注")
                    TextField("≤200 字（可空）", text: $note)
                        .textFieldStyle(.roundedBorder).frame(width: 260)
                }
            }

            if let error {
                Text(error).font(.system(size: 11)).foregroundColor(Theme.danger).padding(.top, 10)
            }
            if existing == nil {
                Text("记一笔永远只新增；提交后服务器会返回这笔的 id，之后才能改它。")
                    .font(.system(size: 10)).foregroundColor(Theme.textLight).padding(.top, 8)
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("取消").font(.system(size: 12))
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Theme.surfaceSoft).foregroundColor(Theme.textMain)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)

                Button { Task { await submit() } } label: {
                    if submitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("保存").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white).clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(submitting)
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(width: 420)
        .background(Theme.card)
        .onAppear {
            date = existing?.date ?? state.serverToday
            title = existing?.title ?? ""
            amount = existing.map { NLFormat.money($0.amount) } ?? ""
            kind = existing?.kind ?? "other"
            shop = existing?.shop ?? ""
            note = existing?.note ?? ""
        }
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
    }

    private func submit() async {
        error = nil
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { error = "要填品名"; return }
        guard t.count <= 60 else { error = "品名超了 60 字"; return }
        guard let a = Double(amount.replacingOccurrences(of: ",", with: "")) else { error = "金额要填数字"; return }
        guard (0.01...100000).contains(a) else { error = "金额要在 0.01 – 100000 元之间"; return }
        guard shop.count <= 40 else { error = "购买地点超了 40 字"; return }
        guard note.count <= 200 else { error = "备注超了 200 字"; return }
        let rounded = (a * 100).rounded() / 100
        submitting = true
        defer { submitting = false }
        let ok: Bool
        if let bill = existing {
            ok = await state.updateBill(id: bill.id, fields: [
                "date": date, "title": t, "amount": rounded, "kind": kind, "shop": shop, "note": note,
            ])
        } else {
            ok = await state.addBill(date: date, title: t, amount: rounded, kind: kind, shop: shop, note: note)
        }
        if ok { dismiss() } else { error = state.lastError ?? "保存失败" }
    }
}

// MARK: - 记账：右栏看板

struct BillsDetailView: View {
    @EnvironmentObject var state: AppState
    @State private var showEditor = false

    var body: some View {
        Group {
            if state.siteKey.isEmpty {
                KeyMissing()
            } else if let b = state.billsData {
                content(b)
            } else if state.siteDataLoading {
                VStack { ProgressView(); Text("正在读取站点数据…").font(.system(size: 11)).foregroundColor(Theme.textLight) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            } else {
                VStack(spacing: 12) {
                    EmptyStateView(title: "读不到站点数据",
                                   subtitle: state.siteDataError ?? "点下面的按钮重试")
                    Button { Task { await state.refreshSiteData() } } label: {
                        Text("重试").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.accent).foregroundColor(.white).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showEditor) { BillEditSheet(existing: nil) }
    }

    private func content(_ b: BillsData) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    InlineActionButton(title: "记一笔", icon: "plus") { showEditor = true }
                    Spacer()
                    Text("\(b.count ?? 0) 笔 · 共 ¥" + NLFormat.money(b.totals?.amount ?? 0))
                        .font(.system(size: 11)).foregroundColor(Theme.textLight)
                }
                HStack(spacing: 12) {
                    periodCard("本周", now: b.week, prev: b.prev_week,
                               context: b.span.map { "第 \($0.weekday ?? 0)/7 天" } ?? "")
                    periodCard("本月", now: b.month, prev: b.prev_month,
                               context: b.span.map { "\($0.month_day_of ?? 0)/\($0.month_days ?? 0) 天" } ?? "")
                    periodCard("累计", now: b.totals, prev: nil, context: "")
                }

                SectionCard("近 7 个月", subtitle: "含本月，没记的月份也是 0") {
                    MonthBars(months: b.months ?? [])
                }

                SectionCard("本月花在哪", subtitle: (b.kinds_month ?? []).isEmpty ? nil : "按金额排序") {
                    if (b.kinds_month ?? []).isEmpty {
                        Text("本月还没开销").font(.system(size: 12)).foregroundColor(Theme.textLight)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(b.kinds_month ?? []) { share in
                                kindRow(share, kinds: b.kinds ?? [])
                            }
                        }
                    }
                }

                if let totals = b.totals {
                    SectionCard("总账") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(totals.count) 笔 · 共 \(b.first ?? "") – \(b.last ?? "")")
                                .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                            HStack(spacing: 14) {
                                if let days = totals.days {
                                    Text("\(days) 天有开销，日均 ¥" + NLFormat.money(totals.avg_day ?? 0))
                                }
                                if let avg = totals.avg_bill {
                                    Text("单均 ¥" + NLFormat.money(avg))
                                }
                            }
                            .font(.system(size: 11)).foregroundColor(Theme.textLight)
                            if let max = totals.max {
                                HStack(spacing: 6) {
                                    Text("最大一笔").font(.system(size: 10)).foregroundColor(Theme.textLight)
                                    Text("\(max.title ?? "") ¥" + NLFormat.money(max.amount ?? 0))
                                        .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.statusDraft)
                                    Text(max.date ?? "").font(.system(size: 10)).foregroundColor(Theme.textLight)
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.bg)
    }

    /// 涨跌由客户端算：本期 - 上期；上期没有记录就显示 —
    private func periodCard(_ name: String, now: BillAggregate?, prev: BillAggregate?, context: String) -> some View {
        let delta: Double? = (prev?.count ?? 0) > 0 ? (now?.amount ?? 0) - prev!.amount : nil
        return StatCard(name, tint: name == "本周" ? Theme.accent : name == "本月" ? Theme.info : Theme.headingMarker) {
            VStack(alignment: .leading, spacing: 3) {
                Text("¥" + NLFormat.money(now?.amount ?? 0))
                    .font(.system(size: 20, weight: .bold)).foregroundColor(Theme.textStrong)
                HStack(spacing: 6) {
                    if let d = delta {
                        Text(NLFormat.signedMoney(d))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(moneyColor(d))
                        Text("比上期" + (d > 0 ? "多" : d < 0 ? "省" : "持平"))
                            .font(.system(size: 9)).foregroundColor(Theme.textLight)
                    } else if prev == nil {
                        Text("共 \(now?.count ?? 0) 笔").font(.system(size: 10)).foregroundColor(Theme.textLight)
                    } else {
                        Text("比上期 —").font(.system(size: 10)).foregroundColor(Theme.textLight)
                    }
                }
                if let now {
                    Text("记录 \(now.days ?? now.count) 天 · 日均 ¥" + NLFormat.money(now.avg_day ?? 0))
                        .font(.system(size: 10)).foregroundColor(Theme.textLight)
                } else {
                    Text("还没有记录").font(.system(size: 10)).foregroundColor(Theme.textLight)
                }
                if !context.isEmpty {
                    Text(context).font(.system(size: 9)).foregroundColor(Theme.textLight).opacity(0.8)
                }
            }
        }
    }

    private func kindRow(_ share: BillKindShare, kinds: [BillKind]) -> some View {
        let label = kinds.first { $0.kind == share.kind }?.label ?? share.kind
        return HStack(spacing: 10) {
            Text(label).font(.system(size: 12)).foregroundColor(Theme.textMain)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceSunken)
                    Capsule().fill(LinearGradient(colors: [Theme.accent, Theme.headingMarker.opacity(0.8)],
                                                 startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * CGFloat(min(max(share.share ?? 0, 0), 1))))
                }
            }
            .frame(height: 6)
            Text("¥" + NLFormat.money(share.amount))
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(Theme.textStrong)
                .frame(width: 62, alignment: .trailing)
            Text(String(format: "%.0f%%", (share.share ?? 0) * 100))
                .font(.system(size: 10)).foregroundColor(Theme.textLight).frame(width: 34, alignment: .trailing)
        }
    }
}

// MARK: - 月度柱状

struct MonthBars: View {
    let months: [BillMonth]

    var body: some View {
        let maxAmount = max(months.map(\.amount).max() ?? 1, 0.01)
        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(months) { m in
                    VStack(spacing: 5) {
                        Text(m.amount > 0 ? NLFormat.money(m.amount) : "0")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(m.amount > 0 ? Theme.textMain : Theme.textLight.opacity(0.5))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(m.amount > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.55)],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Theme.surfaceSunken))
                            .frame(width: 22, height: max(3, 84 * CGFloat(m.amount / maxAmount)))
                        Text(NLDate.monthLabel(m.month))
                            .font(.system(size: 10)).foregroundColor(Theme.textLight)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 126, alignment: .bottom)
        }
    }
}
