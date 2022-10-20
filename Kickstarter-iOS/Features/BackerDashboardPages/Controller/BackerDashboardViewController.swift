import KsApi
import Library
import Prelude
import SwiftUI
import UIKit

internal final class BackerDashboardViewController: UIViewController {
  @IBOutlet private var avatarImageView: CircleAvatarImageView!
  @IBOutlet private var backerNameLabel: UILabel!
  @IBOutlet private var dividerView: UIView!
  @IBOutlet private var embeddedViewTopLayoutConstraint: NSLayoutConstraint!
  @IBOutlet private var headerTopContainerView: UIView!
  @IBOutlet private var backerInfoStackView: UIStackView!
  @IBOutlet private var headerStackView: UIStackView!
  @IBOutlet private var headerView: UIView!
  @IBOutlet private var headerViewTopConstraint: NSLayoutConstraint!
  @IBOutlet private var messagesButtonItem: UIBarButtonItem!
  @IBOutlet private var selectedButtonIndicatorLeadingConstraint: NSLayoutConstraint!
  @IBOutlet private var selectedButtonIndicatorView: UIView!
  @IBOutlet private var selectedButtonIndicatorWidthConstraint: NSLayoutConstraint!
  @IBOutlet private var settingsButtonItem: UIBarButtonItem!
  @IBOutlet private var sortBar: ProfileSortBarView!
  @IBOutlet private var topBackgroundView: UIView!

  fileprivate weak var pageViewController: UIPageViewController?

  fileprivate let viewModel: BackerDashboardViewModel = BackerDashboardViewModel()
  fileprivate var pagesDataSource: BackerDashboardPagesDataSource!

  private var panGesture = UIPanGestureRecognizer()
  private var projectSavedObserver: Any?

  @available(iOS 14.0, *)
  private lazy var backedSavedTabBar =
    UIHostingController(rootView: BackerDashboardTabBarView(
      backedTabText: self.viewModel.backedTabText,
      savedTabText: self.viewModel.savedTabText,
      selectTab: { self.selectTab($0) }
    ))

  internal static func instantiate() -> BackerDashboardViewController {
    return Storyboard.BackerDashboard.instantiate(BackerDashboardViewController.self)
  }

  internal override func viewDidLoad() {
    super.viewDidLoad()

    self.pageViewController = self.children
      .compactMap { $0 as? UIPageViewController }.first
    self.pageViewController?.ksr_setViewControllers(
      [.init()],
      direction: .forward,
      animated: false,
      completion: nil
    )
    self.pageViewController?.delegate = self

    if #available(iOS 14.0, *) {
      self.headerStackView.addSubview(self.backedSavedTabBar.view)
      self.setupConstraints()
    }

    _ = self.messagesButtonItem
      |> UIBarButtonItem.lens.targetAction .~ (self, #selector(self.messagesButtonTapped))

    _ = self.settingsButtonItem
      |> UIBarButtonItem.lens.targetAction .~ (self, #selector(self.settingsButtonTapped))

    self.panGesture.addTarget(self, action: #selector(self.handlePan))
    self.panGesture.delegate = self
    self.view.addGestureRecognizer(self.panGesture)

    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGestureNotifier))
    tapRecognizer.cancelsTouchesInView = false
    self.pageViewController?.view.addGestureRecognizer(tapRecognizer)

    self.projectSavedObserver = NotificationCenter
      .default
      .addObserver(forName: Notification.Name.ksr_projectSaved, object: nil, queue: nil) { [weak self] _ in
        self?.viewModel.inputs.projectSaved()
      }

    self.viewModel.inputs.viewDidLoad()
  }

  deinit {
    self.projectSavedObserver.doIfSome(NotificationCenter.default.removeObserver)
  }

  internal override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    self.viewModel.inputs.viewWillAppear(animated)
  }

  internal override func bindViewModel() {
    super.bindViewModel()

    self.avatarImageView.rac.ksr_imageUrl = self.viewModel.outputs.avatarURL
    self.backerNameLabel.rac.text = self.viewModel.outputs.backerNameText
    self.embeddedViewTopLayoutConstraint.rac.constant =
      self.viewModel.outputs.embeddedViewTopConstraintConstant
    self.sortBar.rac.hidden = self.viewModel.outputs.sortBarIsHidden

    self.viewModel.outputs.configurePagesDataSource
      .observeForControllerAction()
      .observeValues { [weak self] tab, sort in
        self?.configurePagesDataSource(tab: tab, sort: sort)
      }

    self.viewModel.outputs.goToMessages
      .observeForControllerAction()
      .observeValues { [weak self] _ in
        guard let _self = self else { return }
        let vc = MessageThreadsViewController.configuredWith(project: nil, refTag: .profile)
        _self.navigationController?.pushViewController(vc, animated: true)
      }

    self.viewModel.outputs.goToSettings
      .observeForControllerAction()
      .observeValues { [weak self] _ in
        self?.goToSettings()
      }

    self.viewModel.outputs.navigateToTab
      .observeForControllerAction()
      .observeValues { [weak self] tab in
        guard let _self = self, let controller = self?.pagesDataSource.controllerFor(tab: tab) else {
          fatalError("Controller not found for tab \(tab)")
        }
        _self.pageViewController?.ksr_setViewControllers(
          [controller],
          direction: .forward,
          animated: false,
          completion: nil
        )
      }

    self.viewModel.outputs.postNotification
      .observeForUI()
      .observeValues(NotificationCenter.default.post)

    self.viewModel.outputs.updateCurrentUserInEnvironment
      .observeForUI()
      .observeValues { [weak self] user in
        AppEnvironment.updateCurrentUser(user)
        self?.viewModel.inputs.currentUserUpdatedInEnvironment()
      }
  }

  internal override func bindStyles() {
    super.bindStyles()

    _ = self |> baseControllerStyle()

    _ = self.avatarImageView
      |> ignoresInvertColorsImageViewStyle

    _ = self.navigationItem
      |> UINavigationItem.lens.title %~ { _ in Strings.tabbar_profile() }

    _ = self.messagesButtonItem
      |> UIBarButtonItem.lens.image .~ image(named: "inbox-icon")
      |> UIBarButtonItem.lens.accessibilityLabel %~ { _ in Strings.profile_buttons_messages() }

    _ = self.settingsButtonItem
      |> UIBarButtonItem.lens.image .~ image(named: "settings-icon")
      |> UIBarButtonItem.lens.accessibilityLabel %~ { _ in Strings.profile_settings_navbar_title() }

    _ = self.dividerView
      |> UIView.lens.backgroundColor .~ .ksr_support_300

    _ = self.headerStackView
      |> UIView.lens.layoutMargins %~~ { _, view in
        view.traitCollection.isRegularRegular
          ? .init(topBottom: Styles.grid(2), leftRight: Styles.grid(20))
          : .init(top: Styles.grid(5), left: Styles.grid(2), bottom: 0.0, right: Styles.grid(2))
      }

    _ = self.backerNameLabel
      |> UILabel.lens.textColor .~ .ksr_support_700
      |> UILabel.lens.font .~ .ksr_headline(size: 18)
  }

  private func setupConstraints() {
    if #available(iOS 14.0, *) {
      self.backedSavedTabBar.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        self.backedSavedTabBar.view.topAnchor.constraint(equalTo: self.backerInfoStackView.bottomAnchor),
        self.backedSavedTabBar.view.bottomAnchor.constraint(equalTo: self.headerStackView.bottomAnchor),
        self.backedSavedTabBar.view.widthAnchor.constraint(equalTo: self.headerStackView.widthAnchor),
        self.backedSavedTabBar.view.heightAnchor.constraint(equalToConstant: 108)
      ])
    }
  }

  private func configurePagesDataSource(tab: BackerDashboardTab, sort: DiscoveryParams.Sort) {
    self.pagesDataSource = BackerDashboardPagesDataSource(delegate: self, sort: sort)

    self.pageViewController?.dataSource = self.pagesDataSource
    self.pageViewController?.ksr_setViewControllers(
      [self.pagesDataSource.controllerFor(tab: tab)].compact(),
      direction: .forward,
      animated: false,
      completion: nil
    )
  }

  private func setAttributedTitles(for button: UIButton, with string: String) {
    let normalTitleString = NSAttributedString(string: string, attributes: [
      NSAttributedString.Key.font: self.traitCollection.isRegularRegular
        ? UIFont.ksr_headline(size: 16.0)
        : UIFont.ksr_headline(size: 13.0),
      NSAttributedString.Key.foregroundColor: UIColor.ksr_support_400
    ])

    let selectedTitleString = NSAttributedString(string: string, attributes: [
      NSAttributedString.Key.font: self.traitCollection.isRegularRegular
        ? UIFont.ksr_headline(size: 16.0)
        : UIFont.ksr_headline(size: 13.0),
      NSAttributedString.Key.foregroundColor: UIColor.ksr_support_700
    ])

    _ = button
      |> UIButton.lens.attributedTitle(for: .normal) %~ { _ in normalTitleString }
      |> UIButton.lens.attributedTitle(for: .selected) %~ { _ in selectedTitleString }
      |> (UIButton.lens.titleLabel .. UILabel.lens.lineBreakMode) .~ .byWordWrapping
  }

  private func goToSettings() {
    let vc = SettingsViewController.instantiate()
    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .formSheet

    self.present(nav, animated: true, completion: nil)
  }

  private func selectTab(_ tab: BackerDashboardTab) {
    switch tab {
    case .backed:
      self.viewModel.inputs.backedProjectsButtonTapped()
    case .saved:
      self.viewModel.inputs.savedProjectsButtonTapped()
    }
  }

  @objc private func tapGestureNotifier() {
    NotificationCenter.default.post(name: Notification.Name.ksr_savedProjectEmptyStateTapped, object: nil)
  }

  @objc private func messagesButtonTapped() {
    self.viewModel.inputs.messagesButtonTapped()
  }

  @objc private func settingsButtonTapped() {
    self.viewModel.inputs.settingsButtonTapped()
  }

  @objc private func handlePan(gesture: UIPanGestureRecognizer) {
    let selectedTab = self.viewModel.outputs.currentSelectedTab
    guard let controller = self.pagesDataSource.controllerFor(tab: selectedTab) as?
      BackerDashboardProjectsViewController else { return }

    var minHeaderHeight: CGFloat

    if #available(iOS 14.0, *) {
      minHeaderHeight = self.topBackgroundView.frame.size.height
        - self.backedSavedTabBar.view.frame.size.height - Styles.grid(3)
    } else {
      minHeaderHeight = self.topBackgroundView.frame.size.height
        - self.headerStackView.frame.size.height - Styles.grid(3)
    }

    switch gesture.state {
    case .began:
      self.viewModel.inputs.beganPanGestureWith(
        headerTopConstant: self.headerViewTopConstraint.constant,
        scrollViewYOffset: controller.tableView.contentOffset.y
      )
    case .changed:
      let translation = gesture.translation(in: self.view)
      let newConstant = min(0.0, self.viewModel.outputs.initialTopConstant + translation.y)

      if newConstant >= -minHeaderHeight {
        self.headerViewTopConstraint.constant = newConstant
      }

    case .ended:
      let shouldCollapse = self.headerViewTopConstraint.constant < (-minHeaderHeight / 2.0)

      if shouldCollapse {
        UIView.animate(
          withDuration: 0.3,
          delay: 0.0,
          options: .curveEaseOut,
          animations: {
            self.headerViewTopConstraint.constant = -minHeaderHeight
            self.view.layoutIfNeeded()
          },
          completion: nil
        )
      } else {
        UIView.animate(
          withDuration: 0.3,
          delay: 0.0,
          options: .curveEaseOut,
          animations: {
            self.headerViewTopConstraint.constant = 0.0
            self.view.layoutIfNeeded()
          },
          completion: nil
        )
      }
    default: ()
    }
  }
}

extension BackerDashboardViewController: UIPageViewControllerDelegate {
  internal func pageViewController(
    _: UIPageViewController,
    didFinishAnimating _: Bool,
    previousViewControllers _: [UIViewController],
    transitionCompleted completed: Bool
  ) {
    self.viewModel.inputs.pageTransition(completed: completed)
  }

  internal func pageViewController(
    _: UIPageViewController,
    willTransitionTo pendingViewControllers: [UIViewController]
  ) {
    guard let idx = pendingViewControllers.first.flatMap(self.pagesDataSource.indexFor(controller:)) else {
      return
    }

    self.viewModel.inputs.willTransition(toPage: idx)
  }
}

extension BackerDashboardViewController: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }

    let translation = gestureRecognizer.translation(in: self.view)
    if translation.x != 0 { // only respond to horizontal movement.
      return false
    }

    return true
  }

  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
  )
    -> Bool {
    return true
  }
}

extension BackerDashboardViewController: TabBarControllerScrollable {
  func scrollToTop() {
    if let scrollView = self.pageViewController?.viewControllers?.first?.view as? UIScrollView {
      scrollView.scrollToTop()
    }
  }
}
