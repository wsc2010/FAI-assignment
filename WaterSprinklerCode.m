classdef WaterSprinklerCode < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        RightPanel                     matlab.ui.container.Panel
        WaterVolumeAxes                matlab.ui.control.UIAxes
        TemperatureAxes                matlab.ui.control.UIAxes
        RainfallAxes                   matlab.ui.control.UIAxes
        LeftPanel                      matlab.ui.container.Panel
        StartButton                    matlab.ui.control.Button
        WeatherParametersPanel         matlab.ui.container.Panel
        EndDateDatePicker              matlab.ui.control.DatePicker
        EndDateDatePickerLabel         matlab.ui.control.Label
        StartDateDatePicker            matlab.ui.control.DatePicker
        StartDateDatePickerLabel       matlab.ui.control.Label
        ResetAllButton                 matlab.ui.control.Button
        ResetSelectedParameterButton   matlab.ui.control.Button
        UpdateValueEditField           matlab.ui.control.NumericEditField
        UpdateValueEditFieldLabel      matlab.ui.control.Label
        SelectParameterDropDown        matlab.ui.control.DropDown
        SelectParameterDropDownLabel   matlab.ui.control.Label
        UpdateButton                   matlab.ui.control.Button
        DayPeriodButtonGroup           matlab.ui.container.ButtonGroup
        SingleButton                   matlab.ui.control.ToggleButton
        RangeButton                    matlab.ui.control.ToggleButton
        ParameterAxes                  matlab.ui.control.UIAxes
        FuzzyLogicSystemDropDown       matlab.ui.control.DropDown
        FuzzyLogicSystemDropDownLabel  matlab.ui.control.Label
        WaterSprinklerControlSystemLabel  matlab.ui.control.Label
        NeuralNetworkDropDown          matlab.ui.control.DropDown
        NeuralNetworkDropDownLabel     matlab.ui.control.Label
    end

    
    properties (Access = private)
        OriginalData % Original Perth Aug 2016 data
        ModifiedData % User Modified Data
    end
    
    methods (Access = private)
        
        
        function updateParameterGraph(app)
            selectedParameter = app.SelectParameterDropDown.Value;
            plot(app.ParameterAxes, app.ModifiedData.Date, app.ModifiedData.(selectedParameter));
        end
        
        function updateEndDate(app)
            if(app.SingleButton.Value == true)
                app.EndDateDatePicker.Value = app.StartDateDatePicker.Value;
            end
        end

        % Preprocessing for NN input
        function [tempInput, rainfallInput] = preprocessInput(~, inputTable)
            tempParams = ["Humidity3pm","Humidity9am","MaxTemp","MinTemp"];
            rainfallParams = ["Humidity3pm","Humidity9am","Pressure3pm","Pressure9am","Rainfall"];
            tempTable = inputTable(1:end-1, tempParams);
            rainfallTable = inputTable(1:end-1, rainfallParams);
            
            tempInput = table2array(tempTable)';
            rainfallInput = table2array(rainfallTable)';
        end
        
        function [tempResults, rainfallResults] = predictCFNN(~, tempInput, rainfallInput)
            tempResults = cascadeTempModel2(tempInput)';
            rainfallResults = cascadeRainModel(rainfallInput)';
        end
        
        function [tempResults, rainfallResults] = predictFFNN(~, tempInput, rainfallInput)
            tempResults = fitTempModel(tempInput)';
            rainfallResults = fitRainModel(rainfallInput)';
        end
        
        function [tempResults, rainfallResults] = predictRNN(~, tempInput, rainfallInput)
            a = [1 2;3 4; 5 6; 7 8; 9 10; 11 12;13 14; 15 16; 17 18; 19 20];
            tempResults = rnnTempModel(tempInput, a)';
            rainfallResults = rnnRainfallModel(rainfallInput, a)';
        end
        
        function results = evaluateFuzzyA(~, fuzzyInput)
            fuzzyA = readfis('FuzzyA.fis');
            results = evalfis(fuzzyA, fuzzyInput);
        end
        
        function results = evaluateFuzzyB(~, fuzzyInput) %not added
            fuzzyB = readfis('FuzzyA.fis');
            results = evalfis(fuzzyB, fuzzyInput);
        end
        
        function plotOutputGraphs(app, tempResults, rainfallResults, waterResults)
            actualData = app.ModifiedData(2:end,:); %exclude 31-Jul-2016

            plot(app.RainfallAxes, actualData.Date, actualData.Rainfall ,actualData.Date, rainfallResults);
            plot(app.TemperatureAxes, actualData.Date, actualData.Temp9am ,actualData.Date, tempResults);

            plot(app.WaterVolumeAxes, actualData.Date, waterResults);
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.OriginalData = table2timetable(readtable('PerthAug2016.csv'));
            app.ModifiedData = app.OriginalData;

            app.SelectParameterDropDownValueChanged;
        end

        % Value changed function: SelectParameterDropDown
        function SelectParameterDropDownValueChanged(app, event)
            updateParameterGraph(app);
        end

        % Button pushed function: UpdateButton
        function UpdateButtonPushed(app, event)
            selectedParameter = app.SelectParameterDropDown.Value;
            stardDate = app.StartDateDatePicker.Value;
            endDate = app.EndDateDatePicker.Value + 1; %include chosen date

            selectedRange = timerange(stardDate, endDate);
            app.ModifiedData(selectedRange,selectedParameter) = {app.UpdateValueEditField.Value};

            updateParameterGraph(app);
        end

        % Selection changed function: DayPeriodButtonGroup
        function DayPeriodButtonGroupSelectionChanged(app, event)
            if(app.SingleButton.Value == true)
                app.EndDateDatePicker.Enable = false;
            else
                app.EndDateDatePicker.Enable = true;
            end

            updateEndDate(app);
        end

        % Value changed function: StartDateDatePicker
        function StartDateDatePickerValueChanged(app, event)
            updateEndDate(app);
        end

        % Button pushed function: ResetSelectedParameterButton
        function ResetSelectedParameterButtonPushed(app, event)
            selectedParameter = app.SelectParameterDropDown.Value;
            app.ModifiedData.(selectedParameter) =  app.OriginalData.(selectedParameter);
            
            updateParameterGraph(app);
        end

        % Button pushed function: ResetAllButton
        function ResetAllButtonPushed(app, event)
            app.ModifiedData =  app.OriginalData;
            
            updateParameterGraph(app);
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            [tempInput, rainfallInput] = preprocessInput(app, timetable2table(app.ModifiedData));
            switch app.NeuralNetworkDropDown.Value
                case 'CFNN'
                    [tempResults, rainfallResults] = predictCFNN(app, tempInput, rainfallInput);
                case 'FFNN'
                    [tempResults, rainfallResults] = predictFFNN(app, tempInput, rainfallInput);
                case 'RNN'
                    [tempResults, rainfallResults] = predictRNN(app, tempInput, rainfallInput);
            end

            fuzzyIn = horzcat(rainfallResults, tempResults);
            switch app.FuzzyLogicSystemDropDown.Value
                case 'System A'
                    waterResults = evaluateFuzzyA(app, fuzzyIn);
                case 'System B'
                    waterResults = evaluateFuzzyB(app, fuzzyIn);
            end

            plotOutputGraphs(app, tempResults, rainfallResults, waterResults);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 990 687];
            app.UIFigure.Name = 'MATLAB App';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.Position = [1 1 492 687];

            % Create NeuralNetworkDropDownLabel
            app.NeuralNetworkDropDownLabel = uilabel(app.LeftPanel);
            app.NeuralNetworkDropDownLabel.HorizontalAlignment = 'right';
            app.NeuralNetworkDropDownLabel.Position = [44 596 88 22];
            app.NeuralNetworkDropDownLabel.Text = 'Neural Network';

            % Create NeuralNetworkDropDown
            app.NeuralNetworkDropDown = uidropdown(app.LeftPanel);
            app.NeuralNetworkDropDown.Items = {'CFNN', 'FFNN', 'RNN'};
            app.NeuralNetworkDropDown.Position = [172 596 120 22];
            app.NeuralNetworkDropDown.Value = 'CFNN';

            % Create WaterSprinklerControlSystemLabel
            app.WaterSprinklerControlSystemLabel = uilabel(app.LeftPanel);
            app.WaterSprinklerControlSystemLabel.FontSize = 20;
            app.WaterSprinklerControlSystemLabel.Position = [26 641 288 24];
            app.WaterSprinklerControlSystemLabel.Text = 'Water Sprinkler Control System';

            % Create FuzzyLogicSystemDropDownLabel
            app.FuzzyLogicSystemDropDownLabel = uilabel(app.LeftPanel);
            app.FuzzyLogicSystemDropDownLabel.HorizontalAlignment = 'right';
            app.FuzzyLogicSystemDropDownLabel.Position = [44 555 113 22];
            app.FuzzyLogicSystemDropDownLabel.Text = 'Fuzzy Logic System';

            % Create FuzzyLogicSystemDropDown
            app.FuzzyLogicSystemDropDown = uidropdown(app.LeftPanel);
            app.FuzzyLogicSystemDropDown.Items = {'System A', 'System B'};
            app.FuzzyLogicSystemDropDown.Position = [172 555 120 22];
            app.FuzzyLogicSystemDropDown.Value = 'System A';

            % Create WeatherParametersPanel
            app.WeatherParametersPanel = uipanel(app.LeftPanel);
            app.WeatherParametersPanel.BorderType = 'none';
            app.WeatherParametersPanel.Title = 'Weather Parameters';
            app.WeatherParametersPanel.FontSize = 15;
            app.WeatherParametersPanel.Position = [25 13 441 523];

            % Create ParameterAxes
            app.ParameterAxes = uiaxes(app.WeatherParametersPanel);
            title(app.ParameterAxes, 'Title')
            xlabel(app.ParameterAxes, 'X')
            ylabel(app.ParameterAxes, 'Y')
            zlabel(app.ParameterAxes, 'Z')
            app.ParameterAxes.Position = [13 63 404 199];

            % Create DayPeriodButtonGroup
            app.DayPeriodButtonGroup = uibuttongroup(app.WeatherParametersPanel);
            app.DayPeriodButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @DayPeriodButtonGroupSelectionChanged, true);
            app.DayPeriodButtonGroup.BorderType = 'none';
            app.DayPeriodButtonGroup.Title = 'Day Period';
            app.DayPeriodButtonGroup.Position = [38 346 122 100];

            % Create RangeButton
            app.RangeButton = uitogglebutton(app.DayPeriodButtonGroup);
            app.RangeButton.Text = 'Range';
            app.RangeButton.Position = [9 9 100 22];
            app.RangeButton.Value = true;

            % Create SingleButton
            app.SingleButton = uitogglebutton(app.DayPeriodButtonGroup);
            app.SingleButton.Text = 'Single';
            app.SingleButton.Position = [9 47 100 22];

            % Create UpdateButton
            app.UpdateButton = uibutton(app.WeatherParametersPanel, 'push');
            app.UpdateButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateButtonPushed, true);
            app.UpdateButton.Position = [271 291 128 22];
            app.UpdateButton.Text = 'Update';

            % Create SelectParameterDropDownLabel
            app.SelectParameterDropDownLabel = uilabel(app.WeatherParametersPanel);
            app.SelectParameterDropDownLabel.HorizontalAlignment = 'right';
            app.SelectParameterDropDownLabel.Position = [80 462 98 22];
            app.SelectParameterDropDownLabel.Text = 'Select Parameter';

            % Create SelectParameterDropDown
            app.SelectParameterDropDown = uidropdown(app.WeatherParametersPanel);
            app.SelectParameterDropDown.Items = {'Humidity3pm', 'Humidity9am', 'MaxTemp', 'MinTemp', 'Pressure3pm', 'Pressure9am'};
            app.SelectParameterDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectParameterDropDownValueChanged, true);
            app.SelectParameterDropDown.Position = [211 462 153 22];
            app.SelectParameterDropDown.Value = 'Humidity3pm';

            % Create UpdateValueEditFieldLabel
            app.UpdateValueEditFieldLabel = uilabel(app.WeatherParametersPanel);
            app.UpdateValueEditFieldLabel.HorizontalAlignment = 'right';
            app.UpdateValueEditFieldLabel.Position = [38 291 77 22];
            app.UpdateValueEditFieldLabel.Text = 'Update Value';

            % Create UpdateValueEditField
            app.UpdateValueEditField = uieditfield(app.WeatherParametersPanel, 'numeric');
            app.UpdateValueEditField.Position = [139 291 105 22];

            % Create ResetSelectedParameterButton
            app.ResetSelectedParameterButton = uibutton(app.WeatherParametersPanel, 'push');
            app.ResetSelectedParameterButton.ButtonPushedFcn = createCallbackFcn(app, @ResetSelectedParameterButtonPushed, true);
            app.ResetSelectedParameterButton.Position = [45 24 153 22];
            app.ResetSelectedParameterButton.Text = 'Reset Selected Parameter';

            % Create ResetAllButton
            app.ResetAllButton = uibutton(app.WeatherParametersPanel, 'push');
            app.ResetAllButton.ButtonPushedFcn = createCallbackFcn(app, @ResetAllButtonPushed, true);
            app.ResetAllButton.Position = [229 24 153 22];
            app.ResetAllButton.Text = 'Reset All';

            % Create StartDateDatePickerLabel
            app.StartDateDatePickerLabel = uilabel(app.WeatherParametersPanel);
            app.StartDateDatePickerLabel.HorizontalAlignment = 'right';
            app.StartDateDatePickerLabel.Position = [174 392 60 22];
            app.StartDateDatePickerLabel.Text = 'Start Date';

            % Create StartDateDatePicker
            app.StartDateDatePicker = uidatepicker(app.WeatherParametersPanel);
            app.StartDateDatePicker.Limits = [datetime([2016 7 31]) datetime([2016 8 31])];
            app.StartDateDatePicker.ValueChangedFcn = createCallbackFcn(app, @StartDateDatePickerValueChanged, true);
            app.StartDateDatePicker.Position = [249 392 150 22];
            app.StartDateDatePicker.Value = datetime([2016 7 31]);

            % Create EndDateDatePickerLabel
            app.EndDateDatePickerLabel = uilabel(app.WeatherParametersPanel);
            app.EndDateDatePickerLabel.HorizontalAlignment = 'right';
            app.EndDateDatePickerLabel.Position = [174 354 56 22];
            app.EndDateDatePickerLabel.Text = 'End Date';

            % Create EndDateDatePicker
            app.EndDateDatePicker = uidatepicker(app.WeatherParametersPanel);
            app.EndDateDatePicker.Limits = [datetime([2016 7 31]) datetime([2016 8 31])];
            app.EndDateDatePicker.Position = [249 354 150 22];
            app.EndDateDatePicker.Value = datetime([2016 7 31]);

            % Create StartButton
            app.StartButton = uibutton(app.LeftPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Position = [326 555 115 63];
            app.StartButton.Text = 'Start';

            % Create RightPanel
            app.RightPanel = uipanel(app.UIFigure);
            app.RightPanel.Position = [492 1 499 687];

            % Create RainfallAxes
            app.RainfallAxes = uiaxes(app.RightPanel);
            title(app.RainfallAxes, 'Rainfall')
            xlabel(app.RainfallAxes, 'X')
            ylabel(app.RainfallAxes, 'Y')
            zlabel(app.RainfallAxes, 'Z')
            app.RainfallAxes.Position = [100 480 300 185];

            % Create TemperatureAxes
            app.TemperatureAxes = uiaxes(app.RightPanel);
            title(app.TemperatureAxes, 'Temperature')
            xlabel(app.TemperatureAxes, 'X')
            ylabel(app.TemperatureAxes, 'Y')
            zlabel(app.TemperatureAxes, 'Z')
            app.TemperatureAxes.Position = [100 273 300 185];

            % Create WaterVolumeAxes
            app.WaterVolumeAxes = uiaxes(app.RightPanel);
            title(app.WaterVolumeAxes, 'Water')
            xlabel(app.WaterVolumeAxes, 'X')
            ylabel(app.WaterVolumeAxes, 'Y')
            zlabel(app.WaterVolumeAxes, 'Z')
            app.WaterVolumeAxes.Position = [99 36 300 185];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = WaterSprinklerCode

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end