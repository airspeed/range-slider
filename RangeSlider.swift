import Foundation
import UIKit
import RxSwift
import RxCocoa
import RxGesture

/// Represents a slider with two handles.
final class RangeSlider: UIView {

    typealias Range = (min: Float, max: Float)

    // MARK: Stored properties

    @IBInspectable var knobSide: CGFloat = 25
    @IBInspectable var barHeight: CGFloat = 5
    @IBInspectable var inactiveBarColor: UIColor = .myposter(.background)
    @IBInspectable var activeBarColor: UIColor = .myposter(.blue)
    @IBInspectable var debug: Bool = false

    private let disposeBag = DisposeBag()
    fileprivate let initialSelectionSubject = ReplaySubject<RangeSlider.Range>.create(bufferSize: 1)
    private let resultSubject = ReplaySubject<RangeSlider.Range>.create(bufferSize: 1)
    var observeResult: Observable<RangeSlider.Range> {
        self.resultSubject
            .asObservable()
            .distinctUntilChanged({ $0.min == $1.min && $0.max == $1.max })
    }

    // MARK: Subviews

    lazy private(set) var measureReferenceBar: UIView = {
        UIView(frame: CGRect(origin: CGPoint(x: knobSide, y: (self.bounds.size.height / 2) - (knobSide / 2)), size: CGSize(width: self.bounds.size.width - 2 * knobSide, height: knobSide)))
    }()
    lazy private(set) var leftKnob: UIView = {
        let knob = UIView(frame: CGRect(x: 0, y: (self.bounds.size.height / 2) - (knobSide / 2), width: knobSide, height: knobSide))
        knob.backgroundColor = .white
        knob.layer.borderWidth = 1
        knob.layer.cornerRadius = knobSide / 2
        knob.layer.borderColor = activeBarColor.cgColor
        return knob
    }()
    lazy private(set) var rightKnob: UIView = {
        let knob = UIView(frame: CGRect(x: self.bounds.size.width - knobSide, y: (self.bounds.size.height / 2) - (knobSide / 2), width: knobSide, height: knobSide))
        knob.backgroundColor = .white
        knob.layer.borderWidth = 1
        knob.layer.cornerRadius = knobSide / 2
        knob.layer.borderColor = activeBarColor.cgColor
        return knob
    }()
    lazy private(set) var leftBar: UIView = {
        let bar = UIView(frame: CGRect(x: 0, y: (self.bounds.size.height / 2) - (barHeight / 2), width: self.leftKnob.frame.minX, height: barHeight))
        bar.backgroundColor = inactiveBarColor
        bar.layer.cornerRadius = barHeight / 5
        return bar
    }()
    lazy private(set) var rightBar: UIView = {
        let bar = UIView(frame: CGRect(x: self.rightKnob.frame.maxX, y: (self.bounds.size.height / 2) - (barHeight / 2), width: self.bounds.size.width - self.rightKnob.frame.maxX, height: barHeight))
        bar.backgroundColor = inactiveBarColor
        bar.layer.cornerRadius = barHeight / 5
        return bar
    }()
    lazy private(set) var middleBar: UIView = {
        let bar = UIView(frame: CGRect(x: knobSide, y: (self.bounds.size.height / 2) - (barHeight / 2), width: self.rightKnob.frame.minX - self.leftKnob.frame.maxX, height: barHeight))
        bar.backgroundColor = activeBarColor
        bar.layer.cornerRadius = barHeight / 5
        return bar
    }()

    // MARK: Custom initializers

    override init(frame: CGRect) {
        self.knobSide = frame.height
        self.barHeight = frame.height / 5
        super.init(frame: frame)
        self.configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.configure()
    }

    // MARK: Tasks

    private func configure() {
        self.configureUI()
        self.configureRx()
    }

    private func configureUI() {
        self.addSubview(measureReferenceBar)
        self.addSubview(leftKnob)
        self.addSubview(rightKnob)
        self.addSubview(leftBar)
        self.addSubview(rightBar)
        self.addSubview(middleBar)
        self.bringSubviewToFront(leftBar)
        self.bringSubviewToFront(rightBar)
        self.bringSubviewToFront(leftKnob)
        self.bringSubviewToFront(rightKnob)

        if debug {
            measureReferenceBar.backgroundColor = .systemTeal
            let quarterView = UIView(frame: CGRect(x: self.measureReferenceBar.frame.size.width / 4 - 1 + knobSide, y: 0, width: 2, height: self.bounds.size.height))
            let middleView = UIView(frame: CGRect(x: self.bounds.size.width / 2 - 1, y: 0, width: 2, height: self.bounds.size.height))
            let lastQuarterView = UIView(frame: CGRect(x: self.measureReferenceBar.frame.size.width / 4 * 3 - 1 + knobSide, y: 0, width: 2, height: self.bounds.size.height))
            quarterView.backgroundColor = .orange
            middleView.backgroundColor = .purple
            lastQuarterView.backgroundColor = .yellow
            self.addSubview(quarterView)
            self.addSubview(middleView)
            self.addSubview(lastQuarterView)
        }
    }

    private func configureRx() {
        let leftKnob = self.leftKnob
        let rightKnob = self.rightKnob
        let knobSide = self.knobSide
        let sliderWidth = self.bounds.size.width
        let leftBar = self.leftBar
        let rightBar = self.rightBar
        let referenceBar = self.measureReferenceBar
        let referenceWidth = referenceBar.bounds.size.width
        let initialSelection = self.initialSelectionSubject.asObservable().distinctUntilChanged {
            $0.min == $1.min && $0.max == $1.max
        }
        .throttle(.milliseconds(100), latest: false, scheduler: MainScheduler.instance)

        let leftPan = leftKnob.rx.panGesture()
            .when(.changed)
            .throttle(.milliseconds(100), latest: true, scheduler: MainScheduler.instance)
        let rightPan = rightKnob.rx.panGesture()
            .when(.changed)
            .throttle(.milliseconds(100), latest: true, scheduler: MainScheduler.instance)

        leftPan
            .do(afterNext: { [weak self] in
                $0.setTranslation(.zero, in: self)
            })
            .map { [weak self] in $0.translation(in: self) }
            .filter { _ in
                leftKnob.frame.maxX <= rightKnob.frame.minX &&
                    leftKnob.frame.minX >= 0
            }
            .map { ($0, isRelative: true) }
            .merge(with: initialSelection.mapAt(\.min).map { (CGPoint(x: CGFloat($0) * referenceWidth, y: 0), isRelative: false) })
            .subscribe(onNext: { translation, isRelative in
                let origin = isRelative ? leftKnob.frame.origin.x : 0
                leftKnob.frame.origin.x = (origin + translation.x).clamp(min: 0, max: rightKnob.frame.minX - knobSide)
                leftBar.frame.size.width = leftKnob.frame.minX
            })
            .disposed(by: self.disposeBag)

        rightPan
            .do(afterNext: { [weak self] in
                $0.setTranslation(.zero, in: self)
            })
            .map { [weak self] in $0.translation(in: self) }
            .filter { _ in
                rightKnob.frame.minX >= leftKnob.frame.maxX &&
                    rightKnob.frame.maxX <= sliderWidth
            }
            .map { ($0, isRelative: true) }
            .merge(with: initialSelection.mapAt(\.max).map { (CGPoint(x: (CGFloat($0) * referenceWidth) - referenceWidth, y: 0), isRelative: false) })
            .subscribe(onNext: { translation, isRelative in
                let origin = isRelative ? rightKnob.frame.origin.x : sliderWidth - knobSide
                rightKnob.frame.origin.x = (origin + translation.x).clamp(min: leftKnob.frame.maxX, max: sliderWidth - knobSide)
                rightBar.frame.origin.x = rightKnob.frame.maxX
                rightBar.frame.size.width = sliderWidth - rightKnob.frame.maxX
            })
            .disposed(by: self.disposeBag)

        let minResult = leftPan.map { [weak self] _ in
            (self?.convert(CGPoint(x: leftKnob.frame.maxX, y: 0), to: referenceBar).x).map { Float($0 / referenceWidth) }
            }
            .unwrap()
            .merge(with: initialSelection.mapAt(\.min))
        let maxResult = rightPan.map { [weak self] _ in
            (self?.convert(CGPoint(x: rightKnob.frame.minX, y: 0), to: referenceBar).x).map { Float($0 / referenceWidth) }
            }
            .unwrap()
            .merge(with: initialSelection.mapAt(\.max))
        Observable.combineLatest(minResult, maxResult) { (min: $0, max: $1) }
            .distinctUntilChanged {
                $0.min == $1.min && $0.max == $1.max
            }
            .bind(to: self.resultSubject)
            .disposed(by: self.disposeBag)
    }

    // MARK: Debug

    deinit {
        Log.info(msg: "\(self) deinited.")
    }
}

extension Reactive where Base: RangeSlider {
    var initialSelection: Binder<RangeSlider.Range> {
        return Binder(self.base) { slider, initialSelection in
            slider.initialSelectionSubject.onNext(initialSelection)
        }
    }
}
