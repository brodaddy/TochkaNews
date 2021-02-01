//
//  MainViewController.swift
//  NewsAppMVVMRx
//
//  Created by Alexander Milgunov on 30.07.2020.
//  Copyright © 2020 Alexander Milgunov. All rights reserved.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxDataSources

typealias Section = AnimatableSectionModel<String, CellViewModel>

class MainViewController: UIViewController, UITableViewDelegate {
    
    private var viewModel: MainViewModel?
    private var tableView: UITableView
    private var refreshControl: UIRefreshControl
    private var activityIndicator: UIActivityIndicatorView
    
    private let disposeBag = DisposeBag()
    
    private var items: Int = 0
    
    private let dataSource = RxTableViewSectionedAnimatedDataSource<Section>(configureCell: { (_, tableView, _, cellViewModel) in
        
            let cell = tableView.dequeueReusableCell(withIdentifier: CellViewController.cellIdentifier)
            (cell as? CellViewController)?.viewModel = cellViewModel
            return cell ?? UITableViewCell()
        }
    )
    
    private func bindViewModel() {
        
        guard let viewModel = viewModel else { return }
        
        //MARK: - ViewModel Inputs
        let appearObservable = rx.viewWillAppear.asDriver()
        let refreshObservable = refreshControl.rx.controlEvent(UIControl.Event.valueChanged).asDriver()
        
        let fetchTopTrigger = Driver.of(appearObservable, refreshObservable).merge()
        let reachedBottomTrigger = tableView.rx.reachedBottom.asDriver()
            
        let input = MainViewModel.Input(fetchTopTrigger: fetchTopTrigger , reachedBottomTrigger: reachedBottomTrigger)
        
        //MARK: - ViewModel Outputs
        let output = viewModel.transform(input: input)
        
        output.isLoading
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)
        
        output.isLoading
            .map { !$0 }
            .drive(activityIndicator.rx.isHidden)
            .disposed(by: disposeBag)
        
        output.title
            .drive(rx.title)
            .disposed(by: disposeBag)
        
        output.cells.asObservable()
            .map { cellViewModels -> [Section] in
                [Section(model: "1", items: cellViewModels)]
            }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    
        output.cells.asObservable()
            .map { $0.count }
            .subscribe(onNext: { [unowned self] cellsCount in
                if self.items < cellsCount {
                    self.tableView.scrollToRow(at: IndexPath(item: self.items, section: 0), at: .bottom, animated: true)
                }
                self.items = cellsCount
            })
            .disposed(by: disposeBag)
        
        output.alert.asObservable()
            .subscribe(onNext: {
                self.showAlert(alertText: "Data error", alertMessage: $0)
            })
            .disposed(by: disposeBag)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = true
        return activityIndicator
    }
    
    private func setupUI() {

        tableView.refreshControl = refreshControl
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.register(CellViewController.self, forCellReuseIdentifier: CellViewController.cellIdentifier)

        view.addSubview(tableView)
        
        tableView.snp.makeConstraints { (make) in
            make.size.equalToSuperview()
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        bindViewModel()
    }

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        self.tableView = UITableView()
        self.refreshControl = UIRefreshControl()
        self.activityIndicator = UIActivityIndicatorView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}