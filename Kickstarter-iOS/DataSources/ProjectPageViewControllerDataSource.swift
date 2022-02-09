import KsApi
import Library
import Prelude
import UIKit

internal final class ProjectPageViewControllerDataSource: ValueCellDataSource {
  internal enum Section: Int {
    case overviewCreatorHeader
    case overview
    case overviewSubpages
    case campaignHeader
    case campaign
    case faqsHeader
    case faqsEmpty
    case faqs
    case faqsAskAQuestion
    case risksHeader
    case risks
    case risksDisclaimer
    case environmentalCommitmentsHeader
    case environmentalCommitments
    case environmentalCommitmentsDisclaimer
  }

  private enum HeaderValue {
    case overview
    case campaign
    case environmentalCommitments
    case faqs
    case risks

    var description: String {
      switch self {
      case .overview:
        return Strings.Overview()
      case .campaign:
        return Strings.Campaign()
      case .environmentalCommitments:
        return Strings.Environmental_Commitments()
      case .faqs:
        return Strings.Frequently_asked_questions()
      case .risks:
        return Strings.Risks_and_challenges()
      }
    }
  }

  func load(
    navigationSection: NavigationSection,
    project: Project,
    refTag: RefTag?,
    isExpandedStates: [Bool]? = nil
  ) {
    // Clear all sections
    self.clearValues()

    switch navigationSection {
    case .overview:
      if currentUserIsCreator(of: project) {
        self.set(
          values: [project],
          cellClass: ProjectPamphletCreatorHeaderCell.self,
          inSection: Section.overviewCreatorHeader.rawValue
        )
      }

      self.set(
        values: [(project, refTag)],
        cellClass: ProjectPamphletMainCell.self,
        inSection: Section.overview.rawValue
      )

      let values: [ProjectPamphletSubpage] = [
        .comments(project.stats.commentsCount as Int?, .first),
        .updates(project.stats.updatesCount as Int?, .last)
      ]

      self.set(
        values: values,
        cellClass: ProjectPamphletSubpageCell.self,
        inSection: Section.overviewSubpages.rawValue
      )
    case .campaign:
      self.set(
        values: [HeaderValue.campaign.description],
        cellClass: ProjectHeaderCell.self,
        inSection: Section.campaignHeader.rawValue
      )

      let htmlViewElements = project.extendedProjectProperties?.story.htmlViewElements ?? []

      htmlViewElements.forEach { element in
        switch element {
        case let element as TextViewElement:
          self
            .appendRow(
              value: element,
              cellClass: TextViewElementCell.self,
              toSection: Section.campaign.rawValue
            )
        case let element as ImageViewElement:

          self.appendRow(
            value: element,
            cellClass: ImageViewElementCell.self,
            toSection: Section.campaign.rawValue
          )
        default:
          break
        }
      }
    case .faq:
      self.set(
        values: [HeaderValue.faqs.description],
        cellClass: ProjectHeaderCell.self,
        inSection: Section.faqsHeader.rawValue
      )

      // Only render this cell for logged in users
      if AppEnvironment.current.currentUser != nil {
        self.set(
          values: [()],
          cellClass: ProjectFAQsAskAQuestionCell.self,
          inSection: Section.faqsAskAQuestion.rawValue
        )
      }

      let projectFAQs = project.extendedProjectProperties?.faqs ?? []

      guard !projectFAQs.isEmpty else {
        self.set(
          values: [()],
          cellClass: ProjectFAQsEmptyStateCell.self,
          inSection: Section.faqsEmpty.rawValue
        )

        return
      }

      guard let isExpandedStates = isExpandedStates else { return }

      let values = projectFAQs.enumerated().map { idx, faq in
        (faq, isExpandedStates[idx])
      }

      self.set(
        values: values,
        cellClass: ProjectFAQsCell.self,
        inSection: Section.faqs.rawValue
      )
    case .risks:
      // Risks are mandatory for creators
      let risks = project.extendedProjectProperties?.risks ?? ""

      self.set(
        values: [HeaderValue.risks.description],
        cellClass: ProjectHeaderCell.self,
        inSection: Section.risksHeader.rawValue
      )

      self.set(
        values: [risks],
        cellClass: ProjectRisksCell.self,
        inSection: Section.risks.rawValue
      )

      self.set(
        values: [()],
        cellClass: ProjectRisksDisclaimerCell.self,
        inSection: Section.risksDisclaimer.rawValue
      )
    case .environmentalCommitments:
      let environmentalCommitments = project.extendedProjectProperties?.environmentalCommitments ?? []

      self.set(
        values: [HeaderValue.environmentalCommitments.description],
        cellClass: ProjectHeaderCell.self,
        inSection: Section.environmentalCommitmentsHeader.rawValue
      )

      self.set(
        values: environmentalCommitments,
        cellClass: ProjectEnvironmentalCommitmentCell.self,
        inSection: Section.environmentalCommitments.rawValue
      )

      self.set(
        values: [()],
        cellClass: ProjectEnvironmentalCommitmentDisclaimerCell.self,
        inSection: Section.environmentalCommitmentsDisclaimer.rawValue
      )
    }
  }

  override func configureCell(tableCell cell: UITableViewCell, withValue value: Any) {
    switch (cell, value) {
    case let (cell as ProjectEnvironmentalCommitmentCell, value as ProjectEnvironmentalCommitment):
      cell.configureWith(value: value)
    case let (cell as ProjectEnvironmentalCommitmentDisclaimerCell, _):
      cell.configureWith(value: ())
    case let (cell as ProjectHeaderCell, value as String):
      cell.configureWith(value: value)
    case let (cell as ProjectFAQsAskAQuestionCell, _):
      cell.configureWith(value: ())
    case let (cell as ProjectFAQsCell, value as (ProjectFAQ, Bool)):
      cell.configureWith(value: value)
    case let (cell as ProjectFAQsEmptyStateCell, _):
      cell.configureWith(value: ())
    case let (cell as ProjectPamphletCreatorHeaderCell, value as Project):
      cell.configureWith(value: value)
    case let (cell as ProjectPamphletMainCell, value as ProjectPamphletMainCellData):
      cell.configureWith(value: value)
    case let (cell as ProjectPamphletSubpageCell, value as ProjectPamphletSubpage):
      cell.configureWith(value: value)
    case let (cell as ProjectRisksCell, value as String):
      cell.configureWith(value: value)
    case let (cell as ProjectRisksDisclaimerCell, _):
      cell.configureWith(value: ())
    case let (cell as TextViewElementCell, value as TextViewElement):
      cell.configureWith(value: value)
    case let (cell as ImageViewElementCell, value as ImageViewElement):
      cell.configureWith(value: value)
    default:
      assertionFailure("Unrecognized combo: \(cell), \(value)")
    }
  }

  // MARK: Helpers

  internal func updateImageViewElementWith(_ imageData: (URL, Data),
                                           imageViewElement: ImageViewElement,
                                           indexPath: IndexPath) {
    let updateElementWithData = imageViewElement
      |> ImageViewElement.lens.data .~ .some(imageData.1)

    self.set(
      value: updateElementWithData,
      cellClass: ImageViewElementCell.self,
      inSection: indexPath.section,
      row: indexPath.row
    )
  }

  internal func imageViewElementWith(urls: [URL],
                                     indexPath: IndexPath) -> (URL, ImageViewElement, IndexPath)? {
    let allURLStrings = urls.map { $0.absoluteString }

    guard let indexPathSection = Section(rawValue: indexPath.section)?.rawValue,
      let imageViewElementItem = self.items(in: indexPathSection)[indexPath.row].value as? ImageViewElement
    else {
      return nil
    }

    for index in 0..<allURLStrings.count {
      if allURLStrings[index] == imageViewElementItem.src {
        return (urls[index], imageViewElementItem, indexPath)
      }
    }

    return nil
  }

  internal func indexPathIsCommentsSubpage(_ indexPath: IndexPath) -> Bool {
    return (self[indexPath] as? ProjectPamphletSubpage)?.isComments == true
  }

  internal func indexPathIsUpdatesSubpage(_ indexPath: IndexPath) -> Bool {
    return (self[indexPath] as? ProjectPamphletSubpage)?.isUpdates == true
  }

  internal func isExpandedValuesForFAQsSection() -> [Bool]? {
    guard let values = self[section: Section.faqs.rawValue] as? [(ProjectFAQ, Bool)] else { return nil }
    return values.map { _, isExpanded in isExpanded }
  }

  public func isIndexPathAnImageViewElement(tableView: UITableView,
                                            indexPath: IndexPath,
                                            section: ProjectPageViewControllerDataSource.Section) -> Bool {
    guard indexPath.section == section.rawValue else { return false }

    if self.numberOfSections(in: tableView) > section.rawValue,
      self.numberOfItems(in: section.rawValue) > indexPath.row,
      let _ = self.items(in: section.rawValue)[indexPath.row].value as? ImageViewElement {
      return true
    }

    return false
  }

  public func isSectionEmpty(in tableView: UITableView, section: Section) -> Bool {
    let sectionValue = section.rawValue

    if self.numberOfSections(in: tableView) > sectionValue {
      return self.numberOfItems(in: sectionValue) == 0
    }
    return true
  }
}
