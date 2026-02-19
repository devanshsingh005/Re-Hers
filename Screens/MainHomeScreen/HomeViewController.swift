//
//  HomeViewController.swift
//  Re-Hearse_v1
//

import UIKit

class HomeViewController: UIViewController {
    
    let navBar = TopNavBar.make(title: "Re-Hearse")
    let scrollView = UIScrollView()
    let contentView = UIStackView()
    var fixedFooter: UIView!

    var dailyGoalProgressView: UIProgressView?
    var dailyGoalTimeLabel: UILabel?
    var dailyGoalContainer: UIView?

    private var practiceTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPracticeTimer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPracticeTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPracticeTimer()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPracticeTimer()
    }

    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
        setupScrollView()
        addCarouselSection()
        addBuildYourBasicsSection()
        addContinueLearningSection()
        addUploadSection()
    }
    
    private func startPracticeTimer() {
        stopPracticeTimer()
        practiceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DailyGoalManager.shared.checkAndResetIfNewDay()
            DailyGoalManager.shared.practiceTimeMinutesToday += 1
        }
    }
    
    private func stopPracticeTimer() {
        practiceTimer?.invalidate()
        practiceTimer = nil
    }

   
}
