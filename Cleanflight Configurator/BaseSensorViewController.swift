//
//  BaseSensorViewController.swift
//  Cleanflight Configurator
//
//  Created by Raphael Jean-Leconte on 04/12/15.
//  Copyright © 2015 Raphael Jean-Leconte. All rights reserved.
//

import UIKit
import Charts

class BaseSensorViewController: UIViewController, FlightDataListener, MSPCommandSender {

    let MaxSampleCount = 300
    
    var chartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        chartView.rightAxis.enabled = false;
        
        chartView.xAxis.enabled = false
        
        chartView.descriptionText = ""
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if vehicle is MSPVehicle {
            msp.addDataListener(self)
            
            msp.addMSPCommandSender(self)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if vehicle is MSPVehicle {
            msp.removeDataListener(self)
        
            msp.removeMSPCommandSender(self)
        }
    }
    
    func makeDataSet(data: [ChartDataEntry], label: String, color: UIColor?) -> LineChartDataSet {
        let dataSet = LineChartDataSet(yVals: data, label: label)
        if (color != nil) {
            dataSet.setColor(color!)
        }
        dataSet.drawCirclesEnabled = false
        dataSet.drawCubicEnabled = false
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.setDrawHighlightIndicators(false)
        dataSet.lineWidth = 2

        return dataSet;
    }
    
    func sendMSPCommands() {
        // Override in derived classes
    }
}
