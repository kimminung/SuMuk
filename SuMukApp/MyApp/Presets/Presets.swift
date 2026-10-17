import Foundation

/// Bundled presets — the five original SuMuk samples, transcribed from `Media/src/originals.py`.
/// Every coordinate is a closed-form expression of the family variable `k`.
nonisolated struct Preset: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let script: String
}

nonisolated enum Presets {
    static let all: [Preset] = [ginkgo, moonJar, plumBlossom, carp, crane, starter]

    static let starter = Preset(id: "starter", title: "빈 시작", subtitle: "선분 가족 하나로 시작", script: """
    // 선분 가족: k = 1 … N 마다 끝점 두 개를 k의 식으로 정의한다
    let a = 7 in [1, 9]
    segments k = 1 ... 500 {
      from ( 1.5·sin(2πk/500 + π/3)^a,  0.25·cos^2(6πk/500) )
      to   ( 0.2·sin(6πk/500 + π/5),   −0.67·sin^2(2πk/500 − π/3) )
    }
    """)

    static let ginkgo = Preset(id: "ginkgo", title: "은행잎", subtitle: "선분 820개 · 잎자루에서 물결치는 가장자리로", script: """
    // 은행잎 — 잎자루에서 가장자리로 펼쳐지는 부채
    ink #141414 width 0.5 alpha 0.45
    let notch = 0.24 in [0, 0.5]
    let ripple = 0.03 in [0, 0.1]

    segments k = 1 ... 700 {
      from ( 0.05·sin(2π·s(k))·sin^2(π·s(k)),  −1 + 0.22·sin^6(π·s(k)) )
      to   ( r(k)·cos(θ(k)),  r(k)·sin(θ(k)) − 0.25 )
    }
    segments k = 1 ... 120 {
      from ( 0.012·cos(6π·v(k)) + 0.08·v(k)^2,  −1 − 0.55·v(k) )
      to   ( −0.012·cos(6π·v(k)) + 0.08·v(k)^2 + 0.02,  −0.98 − 0.55·v(k) )
    }
    where
      s(k) = k/700
      v(k) = k/120
      θ(k) = π/2 + 1.3·(s(k) − 1/2)
      r(k) = 1.15·(1 − notch·exp(−((θ(k) − π/2)/0.08)^2))·(1 + ripple·sin(22·θ(k))·sin(π·s(k)))
    """)

    static let moonJar = Preset(id: "moonjar", title: "달항아리", subtitle: "원 4,400개 · 중심은 항아리 윤곽, 반지름은 붓 압력", script: """
    // 달항아리 — 원의 중심이 항아리 윤곽을 따라가고, 반지름이 붓 압력이다
    ink #1c1c1e width 0.35 alpha 0.5
    let brush = 0.03 in [0.005, 0.08]

    circles k = 1 ... 1800 {
      center ( −r(k) + sway(k),  y(k) )
      radius  w(k)
    }
    circles k = 1 ... 1800 {
      center ( r(k) + sway(k),  y(k) )
      radius  w(k)
    }
    circles k = 1 ... 400 {
      center ( 0.40·cos(2πk/400),  0.88 + 0.07·sin(2πk/400) )
      radius  0.012 + 0.006·cos^2(2πk/400)
    }
    circles k = 1 ... 400 {
      center ( 0.34·cos(2πk/400),  −0.88 + 0.05·sin(2πk/400) )
      radius  0.01 + 0.004·sin^2(2πk/400)
    }
    where
      u(k) = k/1800
      y(k) = −0.86 + 1.72·u(k)
      belly(k) = 0.98·(1 − |y(k)/0.86|^2.4)^(1/2.1)·(1 + 0.06·exp(−((y(k) − 0.15)/0.35)^2))
      foot(k) = 0.34·exp(−(u(k)/0.035)^2)
      neck(k) = 0.40·exp(−((u(k) − 1)/0.03)^2)
      r(k) = max(belly(k), max(foot(k), neck(k)))·(1 + 0.008·sin(26π·u(k)))
      sway(k) = 0.02·sin^2(π·u(k))·sin(2π·u(k))
      w(k) = 0.022 + brush·sin(π·u(k))^1.5·|cos(4π·u(k) + 0.4)|^0.6
    """)

    static let plumBlossom = Preset(id: "plum", title: "매화", subtitle: "원 3,561개 · 꽃잎 5장 × 700 + 수술 60", script: """
    // 매화 — 꽃잎 하나는 꽃잎 축을 따라 미끄러지는 원 700개
    ink #1c1c1e width 0.3 alpha 0.4
    let petal = 0.30 in [0.1, 0.5]

    circles k = 1 ... 3500 {
      center ( ρ(k)·cos(φ(k)) + w(k)·cos(φ(k) + π/2),  ρ(k)·sin(φ(k)) + w(k)·sin(φ(k) + π/2) )
      radius  petal·sin(π·u(k))^0.8·(1 − 0.35·exp(−((u(k) − 1)/0.12)^2))
    }
    circles k = 1 ... 60 {
      center ( L(k)·cos(2πk/60),  L(k)·sin(2πk/60) )
      radius  0.012 + 0.01·cos^2(3·2πk/60)
    }
    circles k = 1 ... 1 {
      center ( 0, 0 )
      radius  0.06
    }
    where
      j(k) = floor((k − 1)/700)
      u(k) = (k − 700·j(k))/700
      φ(k) = π/2 + 2π·j(k)/5
      ρ(k) = 0.18 + 0.72·u(k)
      w(k) = 0.02·sin(9π·u(k))
      L(k) = 0.28 + 0.1·sin^2(5·2πk/60)
    """)

    static let carp = Preset(id: "carp", title: "잉어", subtitle: "선분 2,760개 · 교차 해칭 몸통 + 부채꼴 꼬리", script: """
    // 잉어 — 서로 교차하는 두 해칭 가족이 몸통, 부채꼴이 꼬리와 지느러미
    ink #141414 width 0.4 alpha 0.5
    let shift = 0.22 in [0.05, 0.5]

    segments k = 1 ... 900 {
      from ( px(k),  top(px(k)) )
      to   ( clamp(px(k) + shift, −0.7, 1),  bot(clamp(px(k) + shift, −0.7, 1)) )
    }
    segments k = 1 ... 900 {
      from ( px(k),  top(px(k)) )
      to   ( clamp(px(k) − shift, −0.7, 1),  bot(clamp(px(k) − shift, −0.7, 1)) )
    }
    segments k = 1 ... 500 {
      from ( −0.68 + 0.03·v(k),  0.05·v(k) )
      to   ( −1.15 − 0.18·|v(k)| + 0.08·(1 − v(k)^2)·cos(6π·v(k)),  0.5·v(k)·(1 + 0.1·cos(10π·v(k))) )
    }
    segments k = 1 ... 200 {
      from ( −0.2 + 0.6·w(k),  top(−0.2 + 0.6·w(k)) )
      to   ( −0.35 + 0.6·w(k),  top(−0.2 + 0.6·w(k)) + 0.16·sin(π·w(k))^0.7·(1 + 0.15·cos(14π·w(k))) )
    }
    segments k = 1 ... 200 {
      from ( 0.1 + 0.3·w(k),  bot(0.1 + 0.3·w(k)) )
      to   ( 0.3·w(k),  bot(0.1 + 0.3·w(k)) − 0.13·sin(π·w(k))^0.7 )
    }
    segments k = 1 ... 60 {
      from ( 0.78 + 0.035·cos(2πk/60),  0.06 + 0.035·sin(2πk/60) )
      to   ( 0.78 + 0.035·cos(2πk/60 + 2.4),  0.06 + 0.035·sin(2πk/60 + 2.4) )
    }
    where
      px(k) = −0.7 + 1.7·k/900
      v(k) = −1 + 2·k/500
      w(k) = k/200
      top(x) = 0.34·√(max(1 − x^2, 0))·(1 + 0.25·x)
      bot(x) = −0.26·√(max(1 − x^2, 0))·(1 + 0.25·x)
    """)

    static let crane = Preset(id: "crane", title: "학", subtitle: "선분 2,760개 · sin⁷ 날개 + S자 목", script: """
    // 학 — 날개는 sin^7 포락선, 목은 S자 곡선을 따라가는 띠
    ink #141414 width 0.45 alpha 0.5
    let wing = 7 in [1, 11]

    segments k = 1 ... 1600 {
      from ( 1.7·sin(u(k) + π/3)^wing,  0.20·cos(3·u(k))^2 + 0.05 )
      to   ( 0.15·sin(3·u(k) + π/5),  −0.55·sin(u(k) − π/3)^2 )
    }
    segments k = 1 ... 500 {
      from ( nx(k) + th(k)·nnx(k),  ny(k) + th(k)·nny(k) )
      to   ( nx(k) − th(k)·nnx(k) + 0.02,  ny(k) − th(k)·nny(k) )
    }
    segments k = 1 ... 240 {
      from ( 1.08 + 0.075·cos(2πk/240),  0.37 + 0.05·sin(2πk/240) )
      to   ( 1.08 + 0.075·cos(2πk/240 + 2.2),  0.37 + 0.05·sin(2πk/240 + 2.2) )
    }
    segments k = 1 ... 120 {
      from ( 1.15,  0.385 − 0.02·b(k) )
      to   ( 1.15 + 0.3·b(k)^0.6,  0.36 + 0.005·b(k) )
    }
    segments k = 1 ... 300 {
      from ( lx(k),  ly(k) + 0.01 )
      to   ( lx(k) − 0.03,  ly(k) − 0.01 )
    }
    where
      u(k) = 2πk/1600
      s(k) = k/500
      nx(k) = 0.1 + 0.95·s(k)
      ny(k) = 0.02 + 0.30·s(k)^2 + 0.05·sin(π·s(k))
      dy(k) = 0.6·s(k) + 0.05·π·cos(π·s(k))
      len(k) = √(0.95^2 + dy(k)^2)
      nnx(k) = −dy(k)/len(k)
      nny(k) = 0.95/len(k)
      th(k) = 0.07·(1 − s(k))^0.7 + 0.02
      b(k) = k/120
      leg(k) = mod(k − 1, 150) + 1
      side(k) = floor((k − 1)/150)
      lx(k) = −0.12 − 0.95·leg(k)/150 + 0.06·side(k)
      ly(k) = −0.04 − 0.1·leg(k)/150
    """)
}
