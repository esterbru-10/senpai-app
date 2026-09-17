classdef SenpaiSegmentationApp < handle
    %SenpaiSegmentationApp GUI wrapper for the SENPAI MATLAB workflow.

    properties (Access = private)
        UIFigure matlab.ui.Figure
        MainGrid matlab.ui.container.GridLayout
        TopGrid matlab.ui.container.GridLayout
        ControlTabs matlab.ui.container.TabGroup
        PreviewAxes matlab.ui.control.UIAxes
        LogTextArea matlab.ui.control.TextArea

        InputLabel matlab.ui.control.Label
        OutputField matlab.ui.control.EditField
        ImageInfoLabel matlab.ui.control.Label
        ResultInfoLabel matlab.ui.control.Label
        SliceSlider matlab.ui.control.Slider
        SliceField matlab.ui.control.NumericEditField
        ViewDropDown matlab.ui.control.DropDown
        StopButton matlab.ui.control.Button

        KField matlab.ui.control.NumericEditField
        SigmaField matlab.ui.control.EditField
        BackgroundThresholdField matlab.ui.control.NumericEditField
        ThresholdMethodDropDown matlab.ui.control.DropDown
        ThresholdSummaryLabel matlab.ui.control.Label
        SizeXField matlab.ui.control.NumericEditField
        SizeYField matlab.ui.control.NumericEditField
        SizeZField matlab.ui.control.NumericEditField
        VerboseCheckBox matlab.ui.control.CheckBox
        ParallelCheckBox matlab.ui.control.CheckBox
        CropX1Field matlab.ui.control.NumericEditField
        CropX2Field matlab.ui.control.NumericEditField
        CropY1Field matlab.ui.control.NumericEditField
        CropY2Field matlab.ui.control.NumericEditField
        CropZ1Field matlab.ui.control.NumericEditField
        CropZ2Field matlab.ui.control.NumericEditField

        SomasLabel matlab.ui.control.Label
        MarkersLabel matlab.ui.control.Label
        SomaXYRadiusField matlab.ui.control.NumericEditField
        SomaZRadiusField matlab.ui.control.NumericEditField

        NeuronLabelField matlab.ui.control.NumericEditField
        SkeletonStatusLabel matlab.ui.control.Label
        CompareALabel matlab.ui.control.Label
        CompareBLabel matlab.ui.control.Label
        CompareMetricsLabel matlab.ui.control.Label
    end

    properties (Access = private)
        BaseFolder char = ''
        SenpaiFolder char = ''
        OutputRootFolder char = ''
        InputPath char = ''
        InputName char = ''
        InputFile char = ''
        OutputFolder char = ''
        CurrentSegmentationFolder char = ''
        HasRunOutputFolder logical = false
        ImageInfo struct = struct('Height',0,'Width',0,'Slices',0,'BitDepth',0)
        SliceIndex double = 1

        CIM = []
        SenpaiFinal = []
        ParcelFinal = []
        Somas = []
        SomaHistory = {}
        Markers = []
        SkeletonTree = []
        SkeletonSwc = []
        LastNeuronMask = []
        CompareVolumeA = []
        CompareVolumeB = []
        CompareLabelA char = ''
        CompareLabelB char = ''
        ComparePathA char = ''
        ComparePathB char = ''
        StopRequested logical = false
    end

    methods (Access = public)
        function app = SenpaiSegmentationApp()
            app.BaseFolder = fileparts(mfilename('fullpath'));
            app.SenpaiFolder = fullfile(app.BaseFolder,'SENPAI');
            app.OutputRootFolder = defaultOutputRootFolder(app);
            app.OutputFolder = app.OutputRootFolder;

            if ~isdeployed && isfolder(app.SenpaiFolder)
                addpath(app.SenpaiFolder);
            end

            createComponents(app);
            initializeState(app);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Name','SENPAI Segmentation App', ...
                'Position',[80 80 1320 820]);
            app.UIFigure.WindowKeyPressFcn = @(~,event) keyPressed(app,event);

            app.MainGrid = uigridlayout(app.UIFigure,[3 2]);
            app.MainGrid.RowHeight = {'fit','1x',130};
            app.MainGrid.ColumnWidth = {380,'1x'};
            app.MainGrid.Padding = [12 12 12 12];
            app.MainGrid.RowSpacing = 10;
            app.MainGrid.ColumnSpacing = 10;

            createTopBar(app);
            createControlTabs(app);
            createPreviewPanel(app);
            createLogPanel(app);
        end

        function createTopBar(app)
            app.TopGrid = uigridlayout(app.MainGrid,[2 8]);
            app.TopGrid.Layout.Row = 1;
            app.TopGrid.Layout.Column = [1 2];
            app.TopGrid.RowHeight = {'fit','fit'};
            app.TopGrid.ColumnWidth = {'fit','fit','fit','fit','1x','fit','fit','fit'};
            app.TopGrid.ColumnSpacing = 8;
            app.TopGrid.Padding = [0 0 0 0];

            titleLabel = uilabel(app.TopGrid,'Text','SENPAI');
            titleLabel.FontWeight = 'bold';
            titleLabel.FontSize = 22;
            titleLabel.Layout.Row = [1 2];
            titleLabel.Layout.Column = 1;

            loadButton = uibutton(app.TopGrid,'Text','Load TIFF', ...
                'ButtonPushedFcn',@(~,~) selectImage(app));
            loadButton.Layout.Row = 1;
            loadButton.Layout.Column = 2;

            loadSegButton = uibutton(app.TopGrid,'Text','Load Segmentation', ...
                'ButtonPushedFcn',@(~,~) loadSegmentationResult(app));
            loadSegButton.Layout.Row = 1;
            loadSegButton.Layout.Column = 3;

            loadParcelButton = uibutton(app.TopGrid,'Text','Load Parcellation', ...
                'ButtonPushedFcn',@(~,~) loadParcellationResult(app));
            loadParcelButton.Layout.Row = 1;
            loadParcelButton.Layout.Column = 4;

            outButton = uibutton(app.TopGrid,'Text','Output...', ...
                'ButtonPushedFcn',@(~,~) selectOutputFolder(app));
            outButton.Layout.Row = 1;
            outButton.Layout.Column = 6;

            app.OutputField = uieditfield(app.TopGrid,'text', ...
                'Editable','off');
            app.OutputField.Layout.Row = 1;
            app.OutputField.Layout.Column = 5;

            refreshButton = uibutton(app.TopGrid,'Text','Refresh View', ...
                'ButtonPushedFcn',@(~,~) updatePreview(app));
            refreshButton.Layout.Row = 1;
            refreshButton.Layout.Column = 7;

            resetAnalysisButton = uibutton(app.TopGrid,'Text','New Analysis', ...
                'ButtonPushedFcn',@(~,~) resetAnalysis(app));
            resetAnalysisButton.Layout.Row = 1;
            resetAnalysisButton.Layout.Column = 8;

            app.InputLabel = uilabel(app.TopGrid,'Text','No file loaded');
            app.InputLabel.Layout.Row = 2;
            app.InputLabel.Layout.Column = [2 5];

            app.ImageInfoLabel = uilabel(app.TopGrid,'Text','');
            app.ImageInfoLabel.HorizontalAlignment = 'right';
            app.ImageInfoLabel.Layout.Row = 2;
            app.ImageInfoLabel.Layout.Column = [6 8];
        end

        function createControlTabs(app)
            app.ControlTabs = uitabgroup(app.MainGrid);
            app.ControlTabs.Layout.Row = 2;
            app.ControlTabs.Layout.Column = 1;

            createSegmentationTab(app);
            createParcellationTab(app);
            createMorphometryTab(app);
            createComparisonTab(app);
            createExportTab(app);
        end

        function createSegmentationTab(app)
            tab = uitab(app.ControlTabs,'Title','Segmentation');
            enableScrollable(tab);
            grid = uigridlayout(tab,[20 3]);
            grid.RowHeight = repmat({'fit'},1,20);
            grid.ColumnWidth = {'1x','1x','1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 4;

            section = sectionLabel(grid,'SENPAI Parameters');
            section.Layout.Row = 1;
            section.Layout.Column = [1 3];

            addLabel(grid,'K cluster',2,1);
            app.KField = uieditfield(grid,'numeric','Value',6,'Limits',[2 30], ...
                'RoundFractionalValues','on');
            app.KField.Layout.Row = 2;
            app.KField.Layout.Column = [2 3];

            addLabel(grid,'Sigma',3,1);
            app.SigmaField = uieditfield(grid,'text','Value','0');
            app.SigmaField.Tooltip = 'Examples: 0, -1, 0 3';
            app.SigmaField.Layout.Row = 3;
            app.SigmaField.Layout.Column = [2 3];

            addLabel(grid,'Crop max X',4,1);
            app.SizeXField = uieditfield(grid,'numeric','Value',256,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.SizeXField.Layout.Row = 4;
            app.SizeXField.Layout.Column = [2 3];

            addLabel(grid,'Crop max Y',5,1);
            app.SizeYField = uieditfield(grid,'numeric','Value',256,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.SizeYField.Layout.Row = 5;
            app.SizeYField.Layout.Column = [2 3];

            addLabel(grid,'Crop max Z',6,1);
            app.SizeZField = uieditfield(grid,'numeric','Value',32,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.SizeZField.Layout.Row = 6;
            app.SizeZField.Layout.Column = [2 3];

            app.VerboseCheckBox = uicheckbox(grid,'Text','Keep intermediate files','Value',false);
            app.VerboseCheckBox.Layout.Row = 7;
            app.VerboseCheckBox.Layout.Column = [1 3];

            app.ParallelCheckBox = uicheckbox(grid,'Text','Use parallel pool','Value',true);
            app.ParallelCheckBox.Layout.Row = 8;
            app.ParallelCheckBox.Layout.Column = [1 3];

            thresholdSection = sectionLabel(grid,'Background Threshold');
            thresholdSection.Layout.Row = 9;
            thresholdSection.Layout.Column = [1 3];

            addLabel(grid,'Method',10,1);
            app.ThresholdMethodDropDown = uidropdown(grid, ...
                'Items',{'Otsu','Mean','Median','Mean + 2 STD','Percentile 90','Percentile 95','Percentile 98'}, ...
                'Value','Otsu');
            app.ThresholdMethodDropDown.Layout.Row = 10;
            app.ThresholdMethodDropDown.Layout.Column = [2 3];

            addLabel(grid,'Threshold',11,1);
            app.BackgroundThresholdField = uieditfield(grid,'numeric', ...
                'Value',0, ...
                'Limits',[0 inf], ...
                'ValueChangedFcn',@(~,~) thresholdChanged(app));
            app.BackgroundThresholdField.Layout.Row = 11;
            app.BackgroundThresholdField.Layout.Column = [2 3];

            thresholdButton = uibutton(grid,'Text','Estimate Threshold', ...
                'ButtonPushedFcn',@(~,~) estimateBackgroundThreshold(app));
            thresholdButton.Layout.Row = 12;
            thresholdButton.Layout.Column = [1 2];

            previewThresholdButton = uibutton(grid,'Text','Show Threshold', ...
                'ButtonPushedFcn',@(~,~) showThresholdMode(app));
            previewThresholdButton.Layout.Row = 12;
            previewThresholdButton.Layout.Column = 3;

            app.ThresholdSummaryLabel = uilabel(grid,'Text','Threshold preview: -');
            app.ThresholdSummaryLabel.Layout.Row = 13;
            app.ThresholdSummaryLabel.Layout.Column = [1 3];

            estimateSection = sectionLabel(grid,'K Estimate Crop');
            estimateSection.Layout.Row = 14;
            estimateSection.Layout.Column = [1 3];

            addLabel(grid,'X1 / X2',15,1);
            app.CropX1Field = uieditfield(grid,'numeric','Value',1,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropX1Field.Layout.Row = 15;
            app.CropX1Field.Layout.Column = 2;
            app.CropX2Field = uieditfield(grid,'numeric','Value',128,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropX2Field.Layout.Row = 15;
            app.CropX2Field.Layout.Column = 3;

            addLabel(grid,'Y1 / Y2',16,1);
            app.CropY1Field = uieditfield(grid,'numeric','Value',1,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropY1Field.Layout.Row = 16;
            app.CropY1Field.Layout.Column = 2;
            app.CropY2Field = uieditfield(grid,'numeric','Value',128,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropY2Field.Layout.Row = 16;
            app.CropY2Field.Layout.Column = 3;

            addLabel(grid,'Z1 / Z2',17,1);
            app.CropZ1Field = uieditfield(grid,'numeric','Value',1,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropZ1Field.Layout.Row = 17;
            app.CropZ1Field.Layout.Column = 2;
            app.CropZ2Field = uieditfield(grid,'numeric','Value',32,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.CropZ2Field.Layout.Row = 17;
            app.CropZ2Field.Layout.Column = 3;

            estimateButton = uibutton(grid,'Text','Estimate K', ...
                'ButtonPushedFcn',@(~,~) estimateK(app));
            estimateButton.Layout.Row = 18;
            estimateButton.Layout.Column = [1 3];

            runButton = uibutton(grid,'Text','Run Segmentation', ...
                'ButtonPushedFcn',@(~,~) runSegmentation(app));
            runButton.FontWeight = 'bold';
            runButton.Layout.Row = 19;
            runButton.Layout.Column = [1 3];
        end

        function createParcellationTab(app)
            tab = uitab(app.ControlTabs,'Title','Parcellation');
            grid = uigridlayout(tab,[10 3]);
            grid.RowHeight = repmat({'fit'},1,10);
            grid.ColumnWidth = {'1x','1x','1x'};
            grid.Padding = [10 10 10 10];

            section = sectionLabel(grid,'Marker');
            section.Layout.Row = 1;
            section.Layout.Column = [1 3];

            somasButton = uibutton(grid,'Text','Load somas.mat', ...
                'ButtonPushedFcn',@(~,~) loadMask(app,'somas'));
            somasButton.Layout.Row = 2;
            somasButton.Layout.Column = [1 2];
            app.SomasLabel = uilabel(grid,'Text','not loaded');
            app.SomasLabel.Layout.Row = 2;
            app.SomasLabel.Layout.Column = 3;

            addLabel(grid,'XY / Z radius',3,1);
            app.SomaXYRadiusField = uieditfield(grid,'numeric','Value',12,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.SomaXYRadiusField.Layout.Row = 3;
            app.SomaXYRadiusField.Layout.Column = 2;
            app.SomaZRadiusField = uieditfield(grid,'numeric','Value',3,'Limits',[0 inf], ...
                'RoundFractionalValues','on');
            app.SomaZRadiusField.Layout.Row = 3;
            app.SomaZRadiusField.Layout.Column = 3;

            markSomaButton = uibutton(grid,'Text','Mark Soma by Click', ...
                'ButtonPushedFcn',@(~,~) markSomaFromClick(app));
            markSomaButton.FontWeight = 'bold';
            markSomaButton.Layout.Row = 4;
            markSomaButton.Layout.Column = [1 3];

            undoSomaButton = uibutton(grid,'Text','Undo Soma', ...
                'ButtonPushedFcn',@(~,~) undoLastSoma(app));
            undoSomaButton.Layout.Row = 5;
            undoSomaButton.Layout.Column = 1;

            saveSomaButton = uibutton(grid,'Text','Save somas.mat', ...
                'ButtonPushedFcn',@(~,~) saveSomas(app));
            saveSomaButton.Layout.Row = 5;
            saveSomaButton.Layout.Column = 2;

            clearSomaButton = uibutton(grid,'Text','Clear Somas', ...
                'ButtonPushedFcn',@(~,~) clearSomas(app));
            clearSomaButton.Layout.Row = 5;
            clearSomaButton.Layout.Column = 3;

            markersButton = uibutton(grid,'Text','Load markers.mat', ...
                'ButtonPushedFcn',@(~,~) loadMask(app,'markers'));
            markersButton.Layout.Row = 6;
            markersButton.Layout.Column = [1 2];
            app.MarkersLabel = uilabel(grid,'Text','not loaded');
            app.MarkersLabel.Layout.Row = 6;
            app.MarkersLabel.Layout.Column = 3;

            reloadMarkersButton = uibutton(grid,'Text','Reload Output Markers', ...
                'ButtonPushedFcn',@(~,~) loadMarkersFromOutput(app));
            reloadMarkersButton.Layout.Row = 7;
            reloadMarkersButton.Layout.Column = [1 3];

            section2 = sectionLabel(grid,'Step');
            section2.Layout.Row = 8;
            section2.Layout.Column = [1 3];

            separatorButton = uibutton(grid,'Text','Run SENPAI Separator', ...
                'ButtonPushedFcn',@(~,~) runSeparator(app));
            separatorButton.FontWeight = 'bold';
            separatorButton.Layout.Row = 9;
            separatorButton.Layout.Column = [1 3];

            pruneButton = uibutton(grid,'Text','Open SENPAI Prune GUI', ...
                'ButtonPushedFcn',@(~,~) runPrune(app));
            pruneButton.Layout.Row = 10;
            pruneButton.Layout.Column = [1 3];
        end

        function createMorphometryTab(app)
            tab = uitab(app.ControlTabs,'Title','Morphometry');
            grid = uigridlayout(tab,[12 3]);
            grid.RowHeight = repmat({'fit'},1,12);
            grid.ColumnWidth = {'1x','1x','1x'};
            grid.Padding = [10 10 10 10];

            section = sectionLabel(grid,'Neuron');
            section.Layout.Row = 1;
            section.Layout.Column = [1 3];

            addLabel(grid,'Neuron Label',2,1);
            app.NeuronLabelField = uieditfield(grid,'numeric','Value',1,'Limits',[1 inf], ...
                'RoundFractionalValues','on');
            app.NeuronLabelField.Layout.Row = 2;
            app.NeuronLabelField.Layout.Column = [2 3];

            skeletonButton = uibutton(grid,'Text','Skeletonize / SWC', ...
                'ButtonPushedFcn',@(~,~) runSkeletonization(app));
            skeletonButton.FontWeight = 'bold';
            skeletonButton.Layout.Row = 3;
            skeletonButton.Layout.Column = [1 3];

            strahlerButton = uibutton(grid,'Text','Strahler statistics', ...
                'ButtonPushedFcn',@(~,~) runStrahler(app));
            strahlerButton.Layout.Row = 4;
            strahlerButton.Layout.Column = [1 3];

            app.SkeletonStatusLabel = uilabel(grid,'Text','No skeleton loaded');
            app.SkeletonStatusLabel.Layout.Row = 5;
            app.SkeletonStatusLabel.Layout.Column = [1 3];
        end

        function createComparisonTab(app)
            tab = uitab(app.ControlTabs,'Title','Comparison');
            grid = uigridlayout(tab,[8 3]);
            grid.RowHeight = repmat({'fit'},1,8);
            grid.ColumnWidth = {'1x','1x','1x'};
            grid.Padding = [10 10 10 10];

            section = sectionLabel(grid,'Segmentation A');
            section.Layout.Row = 1;
            section.Layout.Column = [1 3];

            loadAButton = uibutton(grid,'Text','Load Segmentation A', ...
                'ButtonPushedFcn',@(~,~) loadComparisonVolume(app,'A'));
            loadAButton.Layout.Row = 2;
            loadAButton.Layout.Column = [1 3];

            app.CompareALabel = uilabel(grid,'Text','Segmentation A: not loaded');
            app.CompareALabel.Layout.Row = 3;
            app.CompareALabel.Layout.Column = [1 3];

            sectionB = sectionLabel(grid,'Segmentation B');
            sectionB.Layout.Row = 4;
            sectionB.Layout.Column = [1 3];

            loadBButton = uibutton(grid,'Text','Load Segmentation B', ...
                'ButtonPushedFcn',@(~,~) loadComparisonVolume(app,'B'));
            loadBButton.Layout.Row = 5;
            loadBButton.Layout.Column = [1 3];

            app.CompareBLabel = uilabel(grid,'Text','Segmentation B: not loaded');
            app.CompareBLabel.Layout.Row = 6;
            app.CompareBLabel.Layout.Column = [1 3];

            app.CompareMetricsLabel = uilabel(grid,'Text','Metrics: -');
            app.CompareMetricsLabel.Layout.Row = 7;
            app.CompareMetricsLabel.Layout.Column = [1 3];
        end

        function createExportTab(app)
            tab = uitab(app.ControlTabs,'Title','Export');
            grid = uigridlayout(tab,[10 1]);
            grid.RowHeight = repmat({'fit'},1,10);
            grid.ColumnWidth = {'1x'};
            grid.Padding = [10 10 10 10];

            section = sectionLabel(grid,'Volumi');
            section.Layout.Row = 1;
            section.Layout.Column = 1;

            exportSegButton = uibutton(grid,'Text','Export Segmentation TIFF', ...
                'ButtonPushedFcn',@(~,~) exportVolume(app,'segmentation'));
            exportSegButton.Layout.Row = 2;

            exportParcelButton = uibutton(grid,'Text','Export Parcellation TIFF', ...
                'ButtonPushedFcn',@(~,~) exportVolume(app,'parcellation'));
            exportParcelButton.Layout.Row = 3;
        end

        function createPreviewPanel(app)
            panel = uipanel(app.MainGrid,'Title','Preview');
            panel.Layout.Row = 2;
            panel.Layout.Column = 2;

            grid = uigridlayout(panel,[3 1]);
            grid.RowHeight = {'1x','fit','fit'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [8 8 8 8];

            app.PreviewAxes = uiaxes(grid);
            app.PreviewAxes.Layout.Row = 1;
            app.PreviewAxes.Layout.Column = 1;
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
            app.PreviewAxes.Box = 'on';

            sliceGrid = uigridlayout(grid,[1 8]);
            sliceGrid.RowHeight = {'fit'};
            sliceGrid.ColumnWidth = {'fit',34,'1x',34,70,'fit',160,'fit'};
            sliceGrid.Layout.Row = 2;
            sliceGrid.Layout.Column = 1;

            addLabel(sliceGrid,'Slice',1,1);
            previousSliceButton = uibutton(sliceGrid,'Text','<', ...
                'Tooltip','Previous slice', ...
                'ButtonPushedFcn',@(~,~) nudgeSlice(app,-1));
            previousSliceButton.Layout.Row = 1;
            previousSliceButton.Layout.Column = 2;

            app.SliceSlider = uislider(sliceGrid,'Limits',[1 2],'Value',1);
            app.SliceSlider.ValueChangingFcn = @(~,event) sliceChanging(app,event);
            app.SliceSlider.ValueChangedFcn = @(~,~) sliceSliderChanged(app);
            app.SliceSlider.Layout.Row = 1;
            app.SliceSlider.Layout.Column = 3;

            nextSliceButton = uibutton(sliceGrid,'Text','>', ...
                'Tooltip','Next slice', ...
                'ButtonPushedFcn',@(~,~) nudgeSlice(app,1));
            nextSliceButton.Layout.Row = 1;
            nextSliceButton.Layout.Column = 4;

            app.SliceField = uieditfield(sliceGrid,'numeric','Value',1,'Limits',[1 2], ...
                'RoundFractionalValues','on', ...
                'ValueChangedFcn',@(~,~) sliceFieldChanged(app));
            app.SliceField.Layout.Row = 1;
            app.SliceField.Layout.Column = 5;

            addLabel(sliceGrid,'View',1,6);
            app.ViewDropDown = uidropdown(sliceGrid, ...
                'Items',{'Raw','Overlay','Threshold','Segmentation','Parcellation','Comparison'}, ...
                'Value','Overlay', ...
                'ValueChangedFcn',@(~,~) updatePreview(app));
            app.ViewDropDown.Layout.Row = 1;
            app.ViewDropDown.Layout.Column = 7;

            resetButton = uibutton(sliceGrid,'Text','Reset View', ...
                'ButtonPushedFcn',@(~,~) resetView(app));
            resetButton.Layout.Row = 1;
            resetButton.Layout.Column = 8;

            app.ResultInfoLabel = uilabel(grid,'Text','');
            app.ResultInfoLabel.Layout.Row = 3;
            app.ResultInfoLabel.Layout.Column = 1;
        end

        function createLogPanel(app)
            panel = uipanel(app.MainGrid,'Title','Log');
            panel.Layout.Row = 3;
            panel.Layout.Column = [1 2];

            grid = uigridlayout(panel,[1 1]);
            grid.Padding = [8 8 8 8];
            app.LogTextArea = uitextarea(grid,'Editable','off');
            app.LogTextArea.Layout.Row = 1;
            app.LogTextArea.Layout.Column = 1;
        end

        function initializeState(app)
            app.OutputField.Value = app.OutputFolder;
            app.ViewDropDown.Value = 'Overlay';
            addLog(app,'App ready.');
            if ~isdeployed && ~isfolder(app.SenpaiFolder)
                addLog(app,'SENPAI folder not found next to the app.');
            end
            updatePreview(app);
        end

        function selectImage(app)
            [file,path] = uigetfile({'*.tif;*.tiff','TIFF stack (*.tif, *.tiff)'}, ...
                'Select 3-D TIFF Stack');
            if isequal(file,0)
                return
            end
            setInputFile(app,fullfile(path,file));
        end

        function setInputFile(app,filePath)
            info = imfinfo(filePath);
            if numel(info) < 2
                uialert(app.UIFigure,'The selected file does not look like a 3-D TIFF stack.','Invalid File');
                return
            end

            [path,name,ext] = fileparts(filePath);
            app.InputPath = path;
            app.InputName = [name ext];
            app.InputFile = filePath;
            app.ImageInfo = struct('Height',info(1).Height, ...
                'Width',info(1).Width, ...
                'Slices',numel(info), ...
                'BitDepth',info(1).BitDepth);
            app.SliceIndex = max(1,round(numel(info)/2));
            clearAnalysisState(app,false);
            app.HasRunOutputFolder = false;
            app.OutputFolder = app.OutputRootFolder;
            app.OutputField.Value = app.OutputRootFolder;

            app.InputLabel.Text = app.InputName;
            app.ImageInfoLabel.Text = sprintf('%d x %d x %d, %d bit', ...
                app.ImageInfo.Height,app.ImageInfo.Width,app.ImageInfo.Slices,app.ImageInfo.BitDepth);
            configureSliceControls(app);
            configureDefaultCrop(app);
            setDefaultBackgroundThreshold(app);
            app.ViewDropDown.Value = 'Raw';
            addLog(app,['Loaded TIFF: ' filePath]);
            addLog(app,'Output run folder will be created on first save.');
            updatePreview(app);
        end

        function resetAnalysis(app)
            clearAnalysisState(app,true);
            app.ViewDropDown.Value = 'Raw';
            app.HasRunOutputFolder = false;
            app.OutputFolder = app.OutputRootFolder;
            app.OutputField.Value = app.OutputRootFolder;
            configureSliceControlsForSlices(app,2);
            setDefaultBackgroundThreshold(app);
            addLog(app,'New analysis started. Loaded image and results were cleared; files on disk were not deleted.');
            updatePreview(app);
        end

        function clearAnalysisState(app,clearInput)
            app.CIM = [];
            app.SenpaiFinal = [];
            app.ParcelFinal = [];
            app.Somas = [];
            app.SomaHistory = {};
            app.Markers = [];
            app.SkeletonTree = [];
            app.SkeletonSwc = [];
            app.LastNeuronMask = [];
            app.CompareVolumeA = [];
            app.CompareVolumeB = [];
            app.CompareLabelA = '';
            app.CompareLabelB = '';
            app.ComparePathA = '';
            app.ComparePathB = '';
            app.CurrentSegmentationFolder = '';

            if ~isempty(app.SkeletonStatusLabel)
                app.SkeletonStatusLabel.Text = 'No skeleton loaded';
            end
            if ~isempty(app.SomasLabel)
                app.SomasLabel.Text = 'not loaded';
            end
            if ~isempty(app.MarkersLabel)
                app.MarkersLabel.Text = 'not loaded';
            end
            if ~isempty(app.ResultInfoLabel)
                app.ResultInfoLabel.Text = '';
            end
            updateComparisonLabels(app);

            if clearInput
                app.InputPath = '';
                app.InputName = '';
                app.InputFile = '';
                app.ImageInfo = struct('Height',0,'Width',0,'Slices',0,'BitDepth',0);
                app.SliceIndex = 1;
                app.HasRunOutputFolder = false;
                app.OutputFolder = app.OutputRootFolder;
                app.InputLabel.Text = 'No file loaded';
                app.ImageInfoLabel.Text = '';
            end
        end

        function selectOutputFolder(app)
            path = uigetdir(app.OutputRootFolder,'Select SENPAI Output Root Folder');
            if isequal(path,0)
                return
            end
            app.OutputRootFolder = path;
            app.OutputFolder = path;
            app.HasRunOutputFolder = false;
            app.OutputField.Value = path;
            addLog(app,['Output root folder set: ' path]);
        end

        function loadSegmentationResult(app)
            [file,path] = uigetfile({'*.mat','MAT files (*.mat)'}, ...
                'Load senpai_final.mat', ...
                app.OutputFolder);
            if isequal(file,0)
                return
            end

            try
                matPath = fullfile(path,file);
                data = load(matPath);
                if ~isfield(data,'senpai_final')
                    error('SENPAI:MissingSegmentation','Selected MAT file does not contain senpai_final.');
                end
                app.SenpaiFinal = logical(data.senpai_final);
                if isfield(data,'cIM')
                    app.CIM = data.cIM;
                end
                app.CurrentSegmentationFolder = path;
                app.OutputFolder = path;
                app.OutputRootFolder = fileparts(path);
                app.HasRunOutputFolder = true;
                app.OutputField.Value = path;
                app.InputLabel.Text = file;
                configureSliceControlsFromLoadedData(app);
                updateImageInfoFromReference(app);
                app.ViewDropDown.Value = 'Segmentation';
                addLog(app,['Loaded segmentation: ' matPath]);
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function loadParcellationResult(app)
            [file,path] = uigetfile({'*.mat','MAT files (*.mat)'}, ...
                'Load senpai_separator.mat', ...
                app.OutputFolder);
            if isequal(file,0)
                return
            end

            try
                matPath = fullfile(path,file);
                data = load(matPath);
                if ~isfield(data,'parcel_final')
                    error('SENPAI:MissingParcellation','Selected MAT file does not contain parcel_final.');
                end
                app.ParcelFinal = data.parcel_final;
                if isfield(data,'senpai_final')
                    app.SenpaiFinal = logical(data.senpai_final);
                    app.CurrentSegmentationFolder = path;
                end
                if isfield(data,'cIM')
                    app.CIM = data.cIM;
                elseif isempty(app.CIM)
                    tryLoadSegmentationFromFolder(app,path);
                end
                app.OutputFolder = path;
                app.OutputRootFolder = fileparts(path);
                app.HasRunOutputFolder = true;
                app.OutputField.Value = path;
                app.InputLabel.Text = file;
                configureSliceControlsFromLoadedData(app);
                updateImageInfoFromReference(app);
                app.ViewDropDown.Value = 'Parcellation';
                addLog(app,['Loaded parcellation: ' matPath]);
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function estimateK(app)
            try
                validateInputFile(app);
                ensureOutputFolder(app);
                crop = getCropVector(app);
                outDir = createUniqueSubfolder(app,app.OutputFolder,'estimateK');

                runBusy(app,'Estimating K...', ...
                    @(progressFcn,cancelFcn) doEstimateK(app,outDir,crop,progressFcn,cancelFcn));
            catch ME
                showError(app,ME);
            end
        end

        function doEstimateK(app,outDir,crop,progressFcn,cancelFcn)
            oldFolder = pwd;
            cleanup = onCleanup(@() cd(oldFolder));
            Kopt = senpai_estimateK(withFilesep(app.InputPath), ...
                app.InputName,withFilesep(outDir),crop,progressFcn,cancelFcn);
            app.KField.Value = Kopt;
            addLog(app,sprintf('Estimated K: %d',Kopt));
            clear cleanup
        end

        function estimateBackgroundThreshold(app)
            try
                validateInputFile(app);
                method = app.ThresholdMethodDropDown.Value;
                [threshold,details] = Findthresholdbackground(app.InputFile,method);
                app.BackgroundThresholdField.Value = threshold;
                updateThresholdSummary(app,details);
                showThresholdMode(app);
                addLog(app,sprintf('Background threshold estimated with %s: %.4g',method,threshold));
            catch ME
                showError(app,ME);
            end
        end

        function thresholdChanged(app)
            updateThresholdSummary(app,[]);
            showThresholdMode(app);
        end

        function showThresholdMode(app)
            if ~isempty(app.ViewDropDown) && isvalid(app.ViewDropDown)
                app.ViewDropDown.Value = 'Threshold';
            end
            updatePreview(app);
        end

        function runSegmentation(app)
            try
                validateInputFile(app);
                createRunOutputFolder(app);
                addLog(app,['Output run: ' app.OutputFolder]);
                app.ParcelFinal = [];
                app.SkeletonTree = [];
                app.SkeletonSwc = [];
                app.LastNeuronMask = [];
                sigG = parseNumericVector(app.SigmaField.Value,0);
                sizeLim = [app.SizeXField.Value app.SizeYField.Value app.SizeZField.Value];
                sizeLim = max(1,round(sizeLim));
                K = round(app.KField.Value);
                verbmem = logical(app.VerboseCheckBox.Value);
                paralpool = logical(app.ParallelCheckBox.Value);
                backgroundThreshold = currentBackgroundThreshold(app);

                runBusy(app,'Running SENPAI segmentation...', ...
                    @(progressFcn,cancelFcn) doSegmentation(app,sigG,sizeLim,verbmem,paralpool,K,backgroundThreshold,progressFcn,cancelFcn));
            catch ME
                showError(app,ME);
            end
        end

        function doSegmentation(app,sigG,sizeLim,verbmem,paralpool,K,backgroundThreshold,progressFcn,cancelFcn)
            oldFolder = pwd;
            cleanup = onCleanup(@() cd(oldFolder));
            senpai_seg_core_v4(withFilesep(app.InputPath),app.InputName, ...
                withFilesep(app.OutputFolder),sigG,sizeLim,verbmem,paralpool,K, ...
                backgroundThreshold,progressFcn,cancelFcn);
            resultPath = fullfile(app.OutputFolder,'senpai_final.mat');
            data = load(resultPath,'senpai_final','cIM');
            app.SenpaiFinal = logical(data.senpai_final);
            app.CIM = data.cIM;
            app.CurrentSegmentationFolder = app.OutputFolder;
            app.SliceIndex = min(app.SliceIndex,size(app.SenpaiFinal,3));
            configureSliceControlsFromLoadedData(app);
            infoPath = writeSegmentationInfoFile(app,resultPath,sigG,sizeLim,verbmem, ...
                paralpool,K,backgroundThreshold);
            addLog(app,['Segmentation complete: ' resultPath]);
            addLog(app,['Segmentation info saved: ' infoPath]);
            updatePreview(app);
            clear cleanup
        end

        function loadMask(app,kind)
            [file,path] = uigetfile({'*.mat','MAT files (*.mat)'}, ...
                ['Load ' kind], app.OutputFolder);
            if isequal(file,0)
                return
            end

            try
                mask = readMaskFromMat(app,fullfile(path,file),kind);
                if strcmp(kind,'somas')
                    app.Somas = mask;
                    app.SomaHistory = {};
                else
                    app.Markers = mask;
                end
                updateMaskLabels(app);
                addLog(app,[kind ' loaded: ' fullfile(path,file)]);
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function markSomaFromClick(app)
            try
                sz = referenceSize(app);
                if isempty(sz)
                    error('SENPAI:NoReference','Load a TIFF stack or segmentation first.');
                end
                ensureSomaMask(app,sz);

                app.ViewDropDown.Value = 'Overlay';
                updatePreview(app);
                addLog(app,'Select the soma center in the preview.');
                title(app.PreviewAxes,'Click the soma center','Interpreter','none');
                drawnow;

                pointRoi = drawpoint(app.PreviewAxes,'Color',[0.1 0.8 0.2]);
                pointPosition = pointRoi.Position;
                if isvalid(pointRoi)
                    delete(pointRoi);
                end
                addSomaAtPosition(app,pointPosition,app.SliceIndex);
            catch ME
                showError(app,ME);
            end
        end

        function addSomaAtPosition(app,pointPosition,sliceIndex)
            sz = referenceSize(app);
            ensureSomaMask(app,sz);
            pushSomaHistory(app);

            radiusXY = max(1,round(app.SomaXYRadiusField.Value));
            radiusZ = max(0,round(app.SomaZRadiusField.Value));
            row = min(max(pointPosition(2),1),sz(1));
            col = min(max(pointPosition(1),1),sz(2));
            z = min(max(round(sliceIndex),1),sz(3));

            somaMask = createEllipsoidMask(app,sz,row,col,z,radiusXY,radiusZ);
            app.Somas = app.Somas | somaMask;
            updateMaskLabels(app);
            addLog(app,sprintf('Soma added at x=%.1f, y=%.1f, z=%d.',col,row,z));
            updatePreview(app);
        end

        function undoLastSoma(app)
            try
                if isempty(app.SomaHistory)
                    error('SENPAI:NoSomaUndo','No soma edit to undo.');
                end
                app.Somas = app.SomaHistory{end};
                app.SomaHistory(end) = [];
                updateMaskLabels(app);
                addLog(app,'Last soma edit undone.');
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function saveSomas(app)
            try
                if isempty(app.Somas) || ~any(app.Somas(:))
                    error('SENPAI:NoSomas','No soma mask to save.');
                end
                ensureOutputFolder(app);
                somas = logical(app.Somas);
                somaPath = fullfile(app.OutputFolder,'somas.mat');
                save(somaPath,'somas');
                addLog(app,['Somas saved: ' somaPath]);
            catch ME
                showError(app,ME);
            end
        end

        function clearSomas(app)
            try
                if isempty(app.Somas) || ~any(app.Somas(:))
                    error('SENPAI:NoSomas','No soma mask to clear.');
                end
                choice = uiconfirm(app.UIFigure,'Clear the current soma mask?', ...
                    'SENPAI','Options',{'Clear','Cancel'}, ...
                    'DefaultOption',2,'CancelOption',2);
                if ~strcmp(choice,'Clear')
                    return
                end
                pushSomaHistory(app);
                app.Somas = false(referenceSize(app));
                updateMaskLabels(app);
                addLog(app,'Soma mask cleared.');
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function loadComparisonVolume(app,slot)
            [file,path] = uigetfile({'*.mat;*.tif;*.tiff','MAT or TIFF volumes (*.mat, *.tif, *.tiff)'}, ...
                ['Load Segmentation ' slot], app.OutputFolder);
            if isequal(file,0)
                return
            end

            try
                filePath = fullfile(path,file);
                [volume,volumeName] = readComparisonFile(app,filePath);
                setComparisonVolume(app,slot,volume,volumeName,filePath);
                showComparisonIfReady(app);
            catch ME
                showError(app,ME);
            end
        end

        function useCurrentForComparison(app,slot,kind)
            try
                switch kind
                    case 'segmentation'
                        ensureSegmentationLoaded(app);
                        volume = app.SenpaiFinal;
                        label = 'Current segmentation';
                    case 'parcellation'
                        if isempty(app.ParcelFinal)
                            tryLoadParcellationFromOutput(app);
                        end
                        if isempty(app.ParcelFinal)
                            error('SENPAI:MissingParcellation','Run or load parcellation first.');
                        end
                        volume = app.ParcelFinal;
                        label = 'Current parcellation';
                    otherwise
                        error('SENPAI:ComparisonKind','Unsupported comparison type.');
                end
                setComparisonVolume(app,slot,volume,label,app.OutputFolder);
                showComparisonIfReady(app);
            catch ME
                showError(app,ME);
            end
        end

        function setComparisonVolume(app,slot,volume,label,path)
            if ndims(volume) ~= 3
                error('SENPAI:ComparisonDims','Comparison volume must be 3-D.');
            end
            if strcmp(slot,'A')
                if ~isempty(app.CompareVolumeB) && ~isequal(size(volume),size(app.CompareVolumeB))
                    error('SENPAI:ComparisonSize','The two comparison volumes must have the same size.');
                end
                app.CompareVolumeA = volume;
                app.CompareLabelA = label;
                app.ComparePathA = path;
            else
                if ~isempty(app.CompareVolumeA) && ~isequal(size(volume),size(app.CompareVolumeA))
                    error('SENPAI:ComparisonSize','The two comparison volumes must have the same size.');
                end
                app.CompareVolumeB = volume;
                app.CompareLabelB = label;
                app.ComparePathB = path;
            end
            app.SliceIndex = min(app.SliceIndex,size(volume,3));
            configureSliceControlsForSlices(app,size(volume,3));
            updateComparisonLabels(app);
            addLog(app,['Segmentation ' slot ' loaded for comparison: ' label]);
        end

        function showComparisonView(app)
            validateComparison(app);
            app.ViewDropDown.Value = 'Comparison';
            configureSliceControlsForSlices(app,size(app.CompareVolumeA,3));
            app.CompareMetricsLabel.Text = comparisonMetricsText(app);
            updatePreview(app);
        end

        function showComparisonIfReady(app)
            if ~isempty(app.CompareVolumeA) && ~isempty(app.CompareVolumeB)
                showComparisonView(app);
            else
                updateComparisonLabels(app);
            end
        end

        function clearComparison(app)
            app.CompareVolumeA = [];
            app.CompareVolumeB = [];
            app.CompareLabelA = '';
            app.CompareLabelB = '';
            app.ComparePathA = '';
            app.ComparePathB = '';
            updateComparisonLabels(app);
            if strcmp(app.ViewDropDown.Value,'Comparison')
                app.ViewDropDown.Value = 'Raw';
            end
            addLog(app,'Comparison cleared.');
            updatePreview(app);
        end

        function saveBestComparison(app,slot)
            try
                if strcmp(slot,'A')
                    volume = app.CompareVolumeA;
                    label = app.CompareLabelA;
                else
                    volume = app.CompareVolumeB;
                    label = app.CompareLabelB;
                end
                if isempty(volume)
                    error('SENPAI:ComparisonMissing','Segmentation %s is not loaded.',slot);
                end
                ensureOutputFolder(app);
                bestFolder = fullfile(app.OutputFolder,'Best');
                if ~isfolder(bestFolder)
                    mkdir(bestFolder);
                end
                safeName = regexprep(label,'[^A-Za-z0-9._-]','_');
                if isempty(safeName)
                    safeName = ['comparison_' slot];
                end
                [file,path] = uiputfile({'*.tif','TIFF stack (*.tif)'}, ...
                    ['Save volume ' slot ' as best'], fullfile(bestFolder,[safeName '.tif']));
                if isequal(file,0)
                    return
                end
                writeTiffStack(app,volume,fullfile(path,file));
                addLog(app,['Best ' slot ' saved: ' fullfile(path,file)]);
            catch ME
                showError(app,ME);
            end
        end

        function updateComparisonLabels(app)
            if ~isempty(app.CompareALabel)
                if isempty(app.CompareVolumeA)
                    app.CompareALabel.Text = 'Segmentation A: not loaded';
                else
                    app.CompareALabel.Text = sprintf('Segmentation A: %s [%s]',app.CompareLabelA,mat2str(size(app.CompareVolumeA)));
                end
            end
            if ~isempty(app.CompareBLabel)
                if isempty(app.CompareVolumeB)
                    app.CompareBLabel.Text = 'Segmentation B: not loaded';
                else
                    app.CompareBLabel.Text = sprintf('Segmentation B: %s [%s]',app.CompareLabelB,mat2str(size(app.CompareVolumeB)));
                end
            end
            if ~isempty(app.CompareMetricsLabel)
                if isempty(app.CompareVolumeA) || isempty(app.CompareVolumeB)
                    app.CompareMetricsLabel.Text = 'Metrics: -';
                else
                    app.CompareMetricsLabel.Text = comparisonMetricsText(app);
                end
            end
        end

        function validateComparison(app)
            if isempty(app.CompareVolumeA) || isempty(app.CompareVolumeB)
                error('SENPAI:ComparisonMissing','Load both Segmentation A and Segmentation B.');
            end
            if ~isequal(size(app.CompareVolumeA),size(app.CompareVolumeB))
                error('SENPAI:ComparisonSize','The two comparison volumes must have the same size.');
            end
        end

        function text = comparisonMetricsText(app)
            validateComparison(app);
            maskA = app.CompareVolumeA > 0;
            maskB = app.CompareVolumeB > 0;
            intersection = nnz(maskA & maskB);
            unionCount = nnz(maskA | maskB);
            totalA = nnz(maskA);
            totalB = nnz(maskB);
            if totalA + totalB == 0
                diceValue = NaN;
            else
                diceValue = 2*intersection/(totalA+totalB);
            end
            if unionCount == 0
                iouValue = NaN;
            else
                iouValue = intersection/unionCount;
            end
            overlap = maskA & maskB;
            if any(overlap(:))
                labelAgreement = mean(app.CompareVolumeA(overlap) == app.CompareVolumeB(overlap));
                text = sprintf('Metrics: Dice %.3f | IoU %.3f | label match %.3f', ...
                    diceValue,iouValue,labelAgreement);
            else
                text = sprintf('Metrics: Dice %.3f | IoU %.3f | label match -', ...
                    diceValue,iouValue);
            end
        end

        function [volume,volumeName] = readComparisonFile(app,filePath)
            [~,name,ext] = fileparts(filePath);
            if any(strcmpi(ext,{'.tif','.tiff'}))
                volume = readTiffStack(app,filePath);
                volumeName = [name ext];
                return
            end

            if ~strcmpi(ext,'.mat')
                error('SENPAI:ComparisonFile','Unsupported file format.');
            end
            vars = whos('-file',filePath);
            names = {vars.name};
            preferred = {'senpai_final','parcel_final','parcel_ws','WS_m'};
            selected = [];
            for pp = 1:numel(preferred)
                selected = find(strcmp(names,preferred{pp}),1);
                if ~isempty(selected)
                    break
                end
            end
            if isempty(selected)
                isVolume = arrayfun(@(v) numel(v.size)==3 && any(strcmp(v.class, ...
                    {'logical','uint8','uint16','uint32','int16','int32','single','double'})),vars);
                candidates = find(isVolume);
                if isempty(candidates)
                    error('SENPAI:ComparisonFile','No 3-D volume variable found in the MAT file.');
                end
                [idx,ok] = listdlg('PromptString','Choose volume to compare', ...
                    'SelectionMode','single', ...
                    'ListString',names(candidates));
                if ~ok
                    error('SENPAI:NoSelection','No volume selected.');
                end
                selected = candidates(idx);
            end
            data = load(filePath,names{selected});
            volume = data.(names{selected});
            volumeName = [name ':' names{selected}];
        end

        function volume = readTiffStack(~,filePath)
            info = imfinfo(filePath);
            if numel(info) < 1
                error('SENPAI:ComparisonFile','Invalid TIFF file.');
            end
            if info(1).BitDepth <= 8
                volume = zeros(info(1).Height,info(1).Width,numel(info),'uint8');
            else
                volume = zeros(info(1).Height,info(1).Width,numel(info),'uint16');
            end
            for zz = 1:numel(info)
                volume(:,:,zz) = imread(filePath,zz);
            end
        end

        function loadMarkersFromOutput(app)
            try
                markerPath = fullfile(app.OutputFolder,'markers.mat');
                if ~isfile(markerPath)
                    error('SENPAI:MissingMarkers','markers.mat was not found in the output folder.');
                end
                app.Markers = readMaskFromMat(app,markerPath,'markers');
                updateMaskLabels(app);
                addLog(app,['Markers reloaded: ' markerPath]);
                updatePreview(app);
            catch ME
                showError(app,ME);
            end
        end

        function runSeparator(app)
            try
                ensureSegmentationLoaded(app);
                seeds = combinedSeeds(app);
                if ~any(seeds(:))
                    error('SENPAI:MissingSeeds','Load at least one soma or marker mask.');
                end
                outputFolder = getCurrentSegmentationFolder(app);
                app.OutputFolder = outputFolder;
                app.HasRunOutputFolder = true;
                app.OutputField.Value = outputFolder;
                addLog(app,['Parcellation output: ' outputFolder]);
                runBusy(app,'Running watershed parcellation...', ...
                    @(progressFcn,cancelFcn) doSeparator(app,seeds,outputFolder,progressFcn,cancelFcn));
            catch ME
                showError(app,ME);
            end
        end

        function doSeparator(app,seeds,outputFolder,progressFcn,cancelFcn)
            oldFolder = pwd;
            cleanup = onCleanup(@() cd(oldFolder));
            cd(outputFolder);
            app.ParcelFinal = senpai_separator(app.SenpaiFinal,app.CIM,seeds,progressFcn,cancelFcn);
            senpai_final = app.SenpaiFinal;
            cIM = app.CIM;
            save(fullfile(outputFolder,'senpai_separator.mat'),'senpai_final','cIM','seeds','-append');
            addLog(app,['Parcellation complete: ' fullfile(outputFolder,'senpai_separator.mat')]);
            updatePreview(app);
            clear cleanup
        end

        function runPrune(app)
            try
                if isempty(app.ParcelFinal)
                    tryLoadParcellationFromOutput(app);
                end
                if isempty(app.ParcelFinal)
                    error('SENPAI:MissingParcellation','Run or load parcellation first.');
                end
                outputFolder = getCurrentSegmentationFolder(app);
                app.OutputFolder = outputFolder;
                app.OutputField.Value = outputFolder;
                pruneMarkers = getPruneMarkers(app);
                firstLabel = max(1,round(app.NeuronLabelField.Value));

                oldFolder = pwd;
                cleanup = onCleanup(@() cd(oldFolder));
                cd(outputFolder);
                senpai_prune(app.ParcelFinal,firstLabel,pruneMarkers);
                clear cleanup
                addLog(app,'senpai_prune opened. Use Save in the prune window to update markers.mat.');
            catch ME
                showError(app,ME);
            end
        end

        function runSkeletonization(app)
            try
                ensureSegmentationLoaded(app);
                if isempty(app.Somas)
                    error('SENPAI:MissingSomas','Load a soma mask before skeletonization.');
                end
                ensureOutputFolder(app);
                label = max(1,round(app.NeuronLabelField.Value));
                neuron = currentNeuronMask(app,label);
                runBusy(app,'Running SENPAI skeletonization...', ...
                    @(~,~) doSkeletonization(app,neuron,label));
            catch ME
                showError(app,ME);
            end
        end

        function doSkeletonization(app,neuron,label)
            [t,swc] = senpai_skeletonize(app.CIM,neuron,app.Somas);
            app.SkeletonTree = t;
            app.SkeletonSwc = swc;
            app.LastNeuronMask = neuron;
            matFile = fullfile(app.OutputFolder,sprintf('senpai_skeleton_label_%d.mat',label));
            swcFile = fullfile(app.OutputFolder,sprintf('senpai_skeleton_label_%d.swc',label));
            t = app.SkeletonTree;
            swc = app.SkeletonSwc;
            save(matFile,'t','swc','label');
            writematrix(app.SkeletonSwc,swcFile,'Delimiter',' ','FileType','text');
            app.SkeletonStatusLabel.Text = sprintf('Skeleton label %d: %d nodes',label,size(app.SkeletonSwc,1));
            addLog(app,['SENPAI skeleton saved: ' swcFile]);
        end

        function runStrahler(app)
            try
                if isempty(app.SkeletonSwc) || isempty(app.LastNeuronMask)
                    error('SENPAI:MissingSkeleton','Run Skeletonize / SWC first.');
                end
                ensureOutputFolder(app);
                label = max(1,round(app.NeuronLabelField.Value));
                runBusy(app,'Running Strahler statistics...', ...
                    @(~,~) doStrahler(app,label));
            catch ME
                showError(app,ME);
            end
        end

        function doStrahler(app,label)
            filename = sprintf('senpai_strahler_label_%d',label);
            senpai_strahlerord(app.SkeletonSwc,app.LastNeuronMask, ...
                withFilesep(app.OutputFolder),filename);
            addLog(app,['Strahler statistics saved: ' fullfile(app.OutputFolder,[filename '.mat'])]);
        end

        function exportVolume(app,kind)
            try
                switch kind
                    case 'segmentation'
                        data = app.SenpaiFinal;
                        defaultName = 'senpai_segmentation.tif';
                    case 'parcellation'
                        data = app.ParcelFinal;
                        defaultName = 'senpai_parcellation.tif';
                    otherwise
                        error('SENPAI:ExportKind','Unsupported export type.');
                end

                if isempty(data)
                    error('SENPAI:MissingVolume','Volume is not available for export.');
                end

                [file,path] = uiputfile({'*.tif','TIFF stack (*.tif)'}, ...
                    'Export Volume', fullfile(app.OutputFolder,defaultName));
                if isequal(file,0)
                    return
                end
                writeTiffStack(app,data,fullfile(path,file));
                addLog(app,['Export complete: ' fullfile(path,file)]);
            catch ME
                showError(app,ME);
            end
        end

        function sliceChanging(app,event)
            app.SliceIndex = round(event.Value);
            app.SliceField.Value = app.SliceIndex;
            title(app.PreviewAxes,sprintf('%s - slice %d',app.ViewDropDown.Value,app.SliceIndex), ...
                'Interpreter','none');
        end

        function sliceSliderChanged(app)
            app.SliceIndex = round(app.SliceSlider.Value);
            app.SliceField.Value = app.SliceIndex;
            updatePreview(app);
        end

        function sliceFieldChanged(app)
            app.SliceIndex = round(app.SliceField.Value);
            app.SliceSlider.Value = app.SliceIndex;
            updatePreview(app);
        end

        function keyPressed(app,event)
            if ~isempty(event.Modifier)
                return
            end

            switch event.Key
                case {'leftarrow','downarrow'}
                    nudgeSlice(app,-1);
                case {'rightarrow','uparrow'}
                    nudgeSlice(app,1);
            end
        end

        function nudgeSlice(app,delta)
            if isempty(app.SliceSlider) || ~isvalid(app.SliceSlider)
                return
            end

            limits = round(app.SliceSlider.Limits);
            nextSlice = min(max(round(app.SliceIndex)+delta,limits(1)),limits(2));
            if nextSlice == app.SliceIndex
                return
            end

            app.SliceIndex = nextSlice;
            app.SliceSlider.Value = nextSlice;
            app.SliceField.Value = nextSlice;
            updatePreview(app);
        end

        function resetView(app)
            axis(app.PreviewAxes,'tight');
            axis(app.PreviewAxes,'image');
        end

        function updatePreview(app)
            if isempty(app.PreviewAxes) || ~isvalid(app.PreviewAxes)
                return
            end

            cla(app.PreviewAxes);
            idx = max(1,round(app.SliceIndex));
            raw = [];
            if ~isempty(app.CIM)
                idx = min(idx,size(app.CIM,3));
                raw = app.CIM(:,:,idx);
            elseif ~isempty(app.InputFile) && isfile(app.InputFile)
                idx = min(idx,app.ImageInfo.Slices);
                raw = imread(app.InputFile,idx);
            end
            app.SliceIndex = idx;

            mode = app.ViewDropDown.Value;
            switch mode
                case 'Raw'
                    if isempty(raw)
                        showEmptyAxes(app,'Load a TIFF stack');
                    else
                        showImage(app,raw,'gray');
                    end
                case 'Threshold'
                    showThresholdPreview(app,raw,idx);
                case 'Segmentation'
                    showMaskOrEmpty(app,app.SenpaiFinal,idx,'Segmentation is not available');
                case 'Parcellation'
                    showLabelOrEmpty(app,app.ParcelFinal,idx,'Parcellation is not available',jet(256));
                case 'Comparison'
                    showComparisonOrEmpty(app,idx);
                otherwise
                    if isempty(raw)
                        showEmptyAxes(app,'Load a TIFF stack');
                    else
                        showImage(app,raw,'gray');
                        hold(app.PreviewAxes,'on');
                        drawMaskOverlay(app,app.SenpaiFinal,idx,[1 0.1 0.1],0.50);
                        drawMaskOverlay(app,app.Somas,idx,[0.1 0.8 0.2],0.35);
                        drawMaskOverlay(app,app.Markers,idx,[0.2 0.5 1],0.45);
                        hold(app.PreviewAxes,'off');
                    end
            end
            if ~any(strcmp(mode,{'Comparison','Threshold'}))
                title(app.PreviewAxes,sprintf('%s - slice %d',mode,idx),'Interpreter','none');
            end
            updateResultInfo(app);
        end

        function showComparisonOrEmpty(app,idx)
            if isempty(app.CompareVolumeA) || isempty(app.CompareVolumeB)
                showEmptyAxes(app,'Load Segmentation A and Segmentation B in the Comparison tab');
                return
            end
            if ~isequal(size(app.CompareVolumeA),size(app.CompareVolumeB))
                showEmptyAxes(app,'Comparison volumes have different sizes');
                return
            end
            idx = min(idx,size(app.CompareVolumeA,3));
            maskA = app.CompareVolumeA(:,:,idx) > 0;
            maskB = app.CompareVolumeB(:,:,idx) > 0;
            rgb = zeros([size(maskA) 3]);
            rgb(:,:,1) = maskB;
            rgb(:,:,2) = maskA;
            rgb(:,:,3) = maskB;
            both = maskA & maskB;
            rgb(:,:,1) = max(rgb(:,:,1),both);
            rgb(:,:,2) = max(rgb(:,:,2),both);
            rgb(:,:,3) = max(rgb(:,:,3),both);
            imagesc(app.PreviewAxes,rgb);
            axis(app.PreviewAxes,'image');
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
            title(app.PreviewAxes,sprintf('A green | B magenta | intersection white - slice %d',idx), ...
                'Interpreter','none');
        end

        function showThresholdPreview(app,raw,idx)
            if isempty(raw)
                showEmptyAxes(app,'Load a TIFF stack');
                updateThresholdSummary(app,[]);
                return
            end

            threshold = currentBackgroundThreshold(app);
            mask = double(raw) > threshold;
            showImage(app,raw,'gray');
            hold(app.PreviewAxes,'on');
            backgroundOverlay = cat(3,ones(size(mask)),zeros(size(mask)),ones(size(mask)));
            backgroundImage = imagesc(app.PreviewAxes,backgroundOverlay);
            backgroundImage.AlphaData = 0.10.*~mask;
            foregroundOverlay = cat(3,zeros(size(mask)),ones(size(mask)),zeros(size(mask)));
            foregroundImage = imagesc(app.PreviewAxes,foregroundOverlay);
            foregroundImage.AlphaData = 0.35.*mask;
            hold(app.PreviewAxes,'off');
            title(app.PreviewAxes,sprintf('Threshold %.4g | foreground green | background magenta - slice %d',threshold,idx), ...
                'Interpreter','none');
            updateThresholdSummaryFromMask(app,threshold,mask);
        end

        function showImage(app,img,mapName)
            imagesc(app.PreviewAxes,img);
            axis(app.PreviewAxes,'image');
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
            colormap(app.PreviewAxes,mapName);
        end

        function showMaskOrEmpty(app,vol,idx,message)
            if isempty(vol)
                showEmptyAxes(app,message);
                return
            end
            idx = min(idx,size(vol,3));
            showImage(app,vol(:,:,idx),gray(2));
        end

        function showLabelOrEmpty(app,vol,idx,message,colorMap)
            if isempty(vol)
                showEmptyAxes(app,message);
                return
            end
            idx = min(idx,size(vol,3));
            showImage(app,vol(:,:,idx),colorMap);
        end

        function showEmptyAxes(app,message)
            text(app.PreviewAxes,0.5,0.5,message, ...
                'HorizontalAlignment','center', ...
                'Units','normalized');
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
        end

        function drawMaskOverlay(app,vol,idx,color,alphaValue)
            if isempty(vol) || idx > size(vol,3)
                return
            end
            mask = vol(:,:,idx) > 0;
            if ~any(mask(:))
                return
            end
            overlay = zeros([size(mask) 3]);
            overlay(:,:,1) = color(1);
            overlay(:,:,2) = color(2);
            overlay(:,:,3) = color(3);
            overlayImage = imagesc(app.PreviewAxes,overlay);
            overlayImage.AlphaData = alphaValue.*mask;
        end

        function configureSliceControls(app)
            nSlices = max(2,app.ImageInfo.Slices);
            configureSliceControlsForSlices(app,nSlices);
        end

        function configureSliceControlsForSlices(app,nSlices)
            nSlices = max(2,round(nSlices));
            app.SliceSlider.Limits = [1 nSlices];
            app.SliceSlider.Value = min(app.SliceIndex,nSlices);
            app.SliceSlider.MajorTicks = unique(round(linspace(1,nSlices,min(6,nSlices))));
            app.SliceField.Limits = [1 nSlices];
            app.SliceField.Value = min(app.SliceIndex,nSlices);
        end

        function configureSliceControlsFromLoadedData(app)
            sz = referenceSize(app);
            if isempty(sz)
                return
            end
            app.ImageInfo.Slices = sz(3);
            app.SliceIndex = min(max(1,app.SliceIndex),sz(3));
            configureSliceControls(app);
        end

        function configureDefaultCrop(app)
            if app.ImageInfo.Slices == 0
                return
            end
            app.SizeXField.Value = min(app.ImageInfo.Height,256);
            app.SizeYField.Value = min(app.ImageInfo.Width,256);
            app.SizeZField.Value = min(app.ImageInfo.Slices,64);

            x2 = min(app.ImageInfo.Height,round(app.ImageInfo.Height * 0.75));
            y2 = min(app.ImageInfo.Width,round(app.ImageInfo.Width * 0.75));
            z2 = min(app.ImageInfo.Slices,round(app.ImageInfo.Slices * 0.75));
            app.CropX1Field.Value = max(1,round(app.ImageInfo.Height * 0.25));
            app.CropX2Field.Value = max(app.CropX1Field.Value,x2);
            app.CropY1Field.Value = max(1,round(app.ImageInfo.Width * 0.25));
            app.CropY2Field.Value = max(app.CropY1Field.Value,y2);
            app.CropZ1Field.Value = max(1,round(app.ImageInfo.Slices * 0.25));
            app.CropZ2Field.Value = max(app.CropZ1Field.Value,z2);
        end

        function setDefaultBackgroundThreshold(app)
            if isempty(app.BackgroundThresholdField) || ~isvalid(app.BackgroundThresholdField)
                return
            end
            bitDepth = max(1,app.ImageInfo.BitDepth);
            app.BackgroundThresholdField.Value = 0.02.*(2.^bitDepth);
            updateThresholdSummary(app,[]);
        end

        function threshold = currentBackgroundThreshold(app)
            if isempty(app.BackgroundThresholdField) || ~isvalid(app.BackgroundThresholdField)
                bitDepth = max(1,app.ImageInfo.BitDepth);
                threshold = 0.02.*(2.^bitDepth);
                return
            end

            threshold = double(app.BackgroundThresholdField.Value);
            if ~isfinite(threshold)
                bitDepth = max(1,app.ImageInfo.BitDepth);
                threshold = 0.02.*(2.^bitDepth);
            end
        end

        function updateThresholdSummary(app,details)
            if isempty(app.ThresholdSummaryLabel) || ~isvalid(app.ThresholdSummaryLabel)
                return
            end
            threshold = currentBackgroundThreshold(app);
            if nargin > 1 && ~isempty(details) && isfield(details,'ForegroundFraction')
                app.ThresholdSummaryLabel.Text = sprintf('Threshold %.4g | foreground %.1f%% over full volume', ...
                    threshold,100.*details.ForegroundFraction);
            else
                app.ThresholdSummaryLabel.Text = sprintf('Threshold %.4g | switch to Threshold view to preview',threshold);
            end
        end

        function updateThresholdSummaryFromMask(app,threshold,mask)
            if isempty(app.ThresholdSummaryLabel) || ~isvalid(app.ThresholdSummaryLabel)
                return
            end
            app.ThresholdSummaryLabel.Text = sprintf('Threshold %.4g | foreground %.1f%% on current slice', ...
                threshold,100.*mean(mask(:)));
        end

        function updateImageInfoFromReference(app)
            sz = referenceSize(app);
            if isempty(sz)
                return
            end
            app.ImageInfo.Height = sz(1);
            app.ImageInfo.Width = sz(2);
            app.ImageInfo.Slices = sz(3);
            if app.ImageInfo.BitDepth > 0
                app.ImageInfoLabel.Text = sprintf('%d x %d x %d, %d bit', ...
                    sz(1),sz(2),sz(3),app.ImageInfo.BitDepth);
            else
                app.ImageInfoLabel.Text = sprintf('%d x %d x %d',sz(1),sz(2),sz(3));
            end
        end

        function updateResultInfo(app)
            parts = {};
            if ~isempty(app.SenpaiFinal)
                parts{end+1} = sprintf('seg voxels: %d',nnz(app.SenpaiFinal));
            end
            if ~isempty(app.ParcelFinal)
                parts{end+1} = sprintf('labels: %d',double(max(app.ParcelFinal(:))));
            end
            if ~isempty(app.Somas)
                parts{end+1} = sprintf('soma voxels: %d',nnz(app.Somas));
            end
            if ~isempty(app.Markers)
                parts{end+1} = sprintf('marker voxels: %d',nnz(app.Markers));
            end
            app.ResultInfoLabel.Text = strjoin(parts,' | ');
        end

        function updateMaskLabels(app)
            if isempty(app.Somas)
                app.SomasLabel.Text = 'not loaded';
            else
                app.SomasLabel.Text = sprintf('%d voxels',nnz(app.Somas));
            end
            if isempty(app.Markers)
                app.MarkersLabel.Text = 'not loaded';
            else
                app.MarkersLabel.Text = sprintf('%d voxels',nnz(app.Markers));
            end
            updateResultInfo(app);
        end

        function crop = getCropVector(app)
            validateInputFile(app);
            info = imfinfo(app.InputFile);
            limits = [info(1).Height info(1).Width numel(info)];
            crop = round([app.CropX1Field.Value app.CropX2Field.Value ...
                app.CropY1Field.Value app.CropY2Field.Value ...
                app.CropZ1Field.Value app.CropZ2Field.Value]);

            if numel(crop) ~= 6 || any(~isfinite(crop))
                crop = [1 limits(1) 1 limits(2) 1 limits(3)];
            end

            starts = [crop(1) crop(3) crop(5)];
            stops = [crop(2) crop(4) crop(6)];
            for dim = 1:3
                if starts(dim) > stops(dim)
                    tmp = starts(dim);
                    starts(dim) = stops(dim);
                    stops(dim) = tmp;
                end

                starts(dim) = max(1,starts(dim));
                stops(dim) = min(limits(dim),stops(dim));

                if starts(dim) > limits(dim) || stops(dim) < 1 || starts(dim) > stops(dim)
                    starts(dim) = 1;
                    stops(dim) = limits(dim);
                end
            end

            crop = [starts(1) stops(1) starts(2) stops(2) starts(3) stops(3)];
            app.CropX1Field.Value = crop(1);
            app.CropX2Field.Value = crop(2);
            app.CropY1Field.Value = crop(3);
            app.CropY2Field.Value = crop(4);
            app.CropZ1Field.Value = crop(5);
            app.CropZ2Field.Value = crop(6);
        end

        function mask = readMaskFromMat(app,matPath,preferredName)
            vars = whos('-file',matPath);
            names = {vars.name};
            selected = find(strcmp(names,preferredName),1);

            if isempty(selected)
                sizes = arrayfun(@(v) numel(v.size)==3,vars);
                candidates = find(sizes);
                if isempty(candidates)
                    error('SENPAI:NoMask','No 3-D variable found in the MAT file.');
                end
                [idx,ok] = listdlg('PromptString','Choose mask variable', ...
                    'SelectionMode','single', ...
                    'ListString',names(candidates));
                if ~ok
                    error('SENPAI:NoSelection','No variable selected.');
                end
                selected = candidates(idx);
            end

            data = load(matPath,names{selected});
            mask = logical(data.(names{selected}));
            ref = referenceSize(app);
            if ~isempty(ref) && ~isequal(size(mask),ref)
                error('SENPAI:MaskSize','The mask does not have the same size as the current volume.');
            end
        end

        function ensureSomaMask(app,sz)
            if isempty(app.Somas)
                app.Somas = false(sz);
            elseif ~isequal(size(app.Somas),sz)
                error('SENPAI:SomaSize','The soma mask does not have the same size as the current volume.');
            end
        end

        function pushSomaHistory(app)
            app.SomaHistory{end+1} = app.Somas;
            if numel(app.SomaHistory) > 20
                app.SomaHistory = app.SomaHistory(end-19:end);
            end
        end

        function mask = createEllipsoidMask(~,sz,row,col,z,radiusXY,radiusZ)
            rowRange = max(1,floor(row-radiusXY)):min(sz(1),ceil(row+radiusXY));
            colRange = max(1,floor(col-radiusXY)):min(sz(2),ceil(col+radiusXY));
            if radiusZ == 0
                zRange = z;
            else
                zRange = max(1,z-radiusZ):min(sz(3),z+radiusZ);
            end

            [rowGrid,colGrid,zGrid] = ndgrid(rowRange,colRange,zRange);
            normalizedDistance = ((rowGrid-row)./radiusXY).^2 + ...
                ((colGrid-col)./radiusXY).^2;
            if radiusZ > 0
                normalizedDistance = normalizedDistance + ((zGrid-z)./radiusZ).^2;
            end

            mask = false(sz);
            mask(rowRange,colRange,zRange) = normalizedDistance <= 1;
        end

        function seeds = combinedSeeds(app)
            sz = referenceSize(app);
            if isempty(sz)
                error('SENPAI:NoReference','Load an image or segmentation first.');
            end
            seeds = false(sz);
            if ~isempty(app.Somas)
                seeds = seeds | logical(app.Somas);
            end
            if ~isempty(app.Markers)
                seeds = seeds | logical(app.Markers);
            end
        end

        function sz = referenceSize(app)
            if ~isempty(app.SenpaiFinal)
                sz = size(app.SenpaiFinal);
            elseif ~isempty(app.ParcelFinal)
                sz = size(app.ParcelFinal);
            elseif ~isempty(app.CIM)
                sz = size(app.CIM);
            elseif app.ImageInfo.Slices > 0
                sz = [app.ImageInfo.Height app.ImageInfo.Width app.ImageInfo.Slices];
            else
                sz = [];
            end
        end

        function neuron = currentNeuronMask(app,label)
            if ~isempty(app.ParcelFinal)
                neuron = app.ParcelFinal == label;
                if ~any(neuron(:))
                    error('SENPAI:MissingLabel','Neuron label was not found in the parcellation.');
                end
            else
                neuron = app.SenpaiFinal > 0;
            end
        end

        function tryLoadParcellationFromOutput(app)
            matPath = fullfile(app.OutputFolder,'senpai_separator.mat');
            if isfile(matPath)
                data = load(matPath,'parcel_final');
                if isfield(data,'parcel_final')
                    app.ParcelFinal = data.parcel_final;
                end
            end
        end

        function tryLoadSegmentationFromFolder(app,folderPath)
            matPath = fullfile(folderPath,'senpai_final.mat');
            if ~isfile(matPath)
                return
            end

            data = load(matPath,'senpai_final','cIM');
            if isfield(data,'senpai_final')
                app.SenpaiFinal = logical(data.senpai_final);
            end
            if isfield(data,'cIM')
                app.CIM = data.cIM;
            end
            app.CurrentSegmentationFolder = folderPath;
        end

        function ensureSegmentationLoaded(app)
            if ~isempty(app.SenpaiFinal) && ~isempty(app.CIM)
                return
            end
            matPath = fullfile(app.OutputFolder,'senpai_final.mat');
            if isfile(matPath)
                data = load(matPath,'senpai_final','cIM');
                if isfield(data,'senpai_final')
                    app.SenpaiFinal = logical(data.senpai_final);
                end
                if isfield(data,'cIM')
                    app.CIM = data.cIM;
                end
                app.CurrentSegmentationFolder = app.OutputFolder;
            end
            if isempty(app.SenpaiFinal) || isempty(app.CIM)
                error('SENPAI:MissingSegmentation','Run or load senpai_final.mat first.');
            end
        end

        function folderPath = getCurrentSegmentationFolder(app)
            if ~isempty(app.CurrentSegmentationFolder) && isfolder(app.CurrentSegmentationFolder) && ...
                    isfile(fullfile(app.CurrentSegmentationFolder,'senpai_final.mat'))
                folderPath = app.CurrentSegmentationFolder;
                return
            end

            if ~isempty(app.OutputFolder) && isfolder(app.OutputFolder) && ...
                    isfile(fullfile(app.OutputFolder,'senpai_final.mat'))
                folderPath = app.OutputFolder;
                app.CurrentSegmentationFolder = folderPath;
                return
            end

            error('SENPAI:MissingSegmentationFolder', ...
                'The current segmentation folder is not available. Run or load a segmentation first.');
        end

        function pruneMarkers = getPruneMarkers(app)
            if isempty(app.Markers) || ~isequal(size(app.Markers),size(app.ParcelFinal))
                pruneMarkers = false(size(app.ParcelFinal));
            else
                pruneMarkers = logical(app.Markers);
            end

            if ~isempty(app.Somas) && isequal(size(app.Somas),size(pruneMarkers))
                pruneMarkers(logical(app.Somas)) = false;
            end
        end

        function infoPath = writeSegmentationInfoFile(app,resultPath,sigG,sizeLim,verbmem,paralpool,K,backgroundThreshold)
            infoPath = fullfile(app.OutputFolder,'info.txt');
            fid = fopen(infoPath,'w');
            if fid < 0
                error('SENPAI:InfoFileError','Unable to create info.txt.');
            end
            cleanup = onCleanup(@() fclose(fid));

            fprintf(fid,'SENPAI segmentation info\n');
            fprintf(fid,'Generated: %s\n',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
            fprintf(fid,'\n');
            fprintf(fid,'Input TIFF: %s\n',app.InputFile);
            fprintf(fid,'Input name: %s\n',app.InputName);
            fprintf(fid,'Output folder: %s\n',app.OutputFolder);
            fprintf(fid,'Segmentation MAT: %s\n',resultPath);
            fprintf(fid,'\n');
            fprintf(fid,'Image height: %d\n',app.ImageInfo.Height);
            fprintf(fid,'Image width: %d\n',app.ImageInfo.Width);
            fprintf(fid,'Image slices: %d\n',app.ImageInfo.Slices);
            fprintf(fid,'Image bit depth: %d\n',app.ImageInfo.BitDepth);
            fprintf(fid,'\n');
            fprintf(fid,'K: %d\n',K);
            fprintf(fid,'Sigma: %s\n',mat2str(sigG));
            fprintf(fid,'Maximum slab size: %s\n',mat2str(sizeLim));
            fprintf(fid,'Background threshold: %.15g\n',backgroundThreshold);
            fprintf(fid,'Verbose memory: %d\n',logical(verbmem));
            fprintf(fid,'Parallel kmeans: %d\n',logical(paralpool));

            clear cleanup
        end

        function ensureOutputFolder(app)
            if ~isempty(app.InputFile) && ~app.HasRunOutputFolder
                createRunOutputFolder(app);
                addLog(app,['Output run: ' app.OutputFolder]);
                return
            end
            if isempty(app.OutputFolder)
                app.OutputFolder = app.OutputRootFolder;
            end
            if ~isfolder(app.OutputFolder)
                mkdir(app.OutputFolder);
            end
            app.OutputField.Value = app.OutputFolder;
        end

        function createRunOutputFolder(app)
            app.OutputRootFolder = getOutputRootFolder(app);
            fileStem = getOutputFolderBaseName(app,'');
            timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
            folderName = [fileStem '_' timestamp];
            candidate = fullfile(app.OutputRootFolder,folderName);
            suffix = 1;
            while isfolder(candidate)
                candidate = fullfile(app.OutputRootFolder,sprintf('%s_%03d',folderName,suffix));
                suffix = suffix + 1;
            end

            mkdir(candidate);
            app.OutputFolder = candidate;
            app.HasRunOutputFolder = true;
            app.OutputField.Value = candidate;
        end

        function rootFolder = getOutputRootFolder(app)
            rootFolder = app.OutputRootFolder;
            if isempty(rootFolder)
                rootFolder = defaultOutputRootFolder(app);
            end
            if ~isfolder(rootFolder)
                mkdir(rootFolder);
            end
        end

        function rootFolder = defaultOutputRootFolder(app)
            if ~isdeployed
                rootFolder = fullfile(app.BaseFolder,'senpai_output');
                return
            end

            if ispc
                homeFolder = getenv('USERPROFILE');
            else
                homeFolder = getenv('HOME');
            end
            if isempty(homeFolder) || ~isfolder(homeFolder)
                homeFolder = tempdir;
            end

            documentsFolder = fullfile(homeFolder,'Documents');
            if ~isfolder(documentsFolder)
                documentsFolder = homeFolder;
            end
            rootFolder = fullfile(documentsFolder,'SENPAI Output');
        end

        function baseName = getOutputFolderBaseName(app,operationName)
            if isempty(app.InputName)
                fileStem = 'senpai_dataset';
            else
                fileStem = regexprep(app.InputName,'[^A-Za-z0-9._-]','_');
            end

            if nargin > 1 && ~isempty(operationName)
                baseName = [fileStem '_' operationName];
            else
                baseName = fileStem;
            end
        end

        function folderPath = createUniqueSubfolder(~,parentFolder,baseName)
            if isempty(parentFolder)
                parentFolder = pwd;
            end
            if ~isfolder(parentFolder)
                mkdir(parentFolder);
            end

            timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
            folderBase = sprintf('%s_%s',baseName,timestamp);
            folderPath = fullfile(parentFolder,folderBase);
            suffix = 1;
            while isfolder(folderPath)
                folderPath = fullfile(parentFolder,sprintf('%s_%03d',folderBase,suffix));
                suffix = suffix + 1;
            end
            mkdir(folderPath);
        end

        function validateInputFile(app)
            if isempty(app.InputFile) || ~isfile(app.InputFile)
                error('SENPAI:MissingInput','Load a 3-D TIFF stack first.');
            end
        end

        function runBusy(app,message,callback)
            addLog(app,message);
            app.StopRequested = false;
            if ~isempty(app.StopButton) && isvalid(app.StopButton)
                app.StopButton.Enable = 'on';
                app.StopButton.Text = 'Stop';
            end
            dialog = uiprogressdlg(app.UIFigure,'Title','SENPAI', ...
                'Message',[message ' (0%)'], ...
                'Indeterminate','off', ...
                'Value',0, ...
                'Cancelable','on', ...
                'CancelText','Stop');
            cleanup = onCleanup(@() finishBusy(app,dialog));
            progressFcn = @(fraction,detail) updateProgress(app,dialog,fraction,detail);
            cancelFcn = @() isStopRequested(app,dialog);
            progressFcn(0,message);
            callback(progressFcn,cancelFcn);
            progressFcn(1,'Complete');
            clear cleanup
        end

        function requestStop(app)
            app.StopRequested = true;
            if ~isempty(app.StopButton) && isvalid(app.StopButton)
                app.StopButton.Text = 'Stop requested';
            end
            addLog(app,'Stop requested. The current operation will stop at the next safe checkpoint.');
            drawnow limitrate
        end

        function stop = isStopRequested(app,dialog)
            drawnow limitrate
            if nargin>1 && ~isempty(dialog) && isvalid(dialog) && dialog.CancelRequested
                app.StopRequested = true;
                if ~isempty(app.StopButton) && isvalid(app.StopButton)
                    app.StopButton.Text = 'Stop requested';
                end
            end
            stop = app.StopRequested;
        end

        function updateProgress(app,dialog,fraction,detail)
            if nargin < 4 || isempty(detail)
                detail = 'Processing';
            end
            fraction = min(max(double(fraction),0),1);
            if ~isempty(dialog) && isvalid(dialog)
                dialog.Value = fraction;
                dialog.Message = sprintf('%s (%d%%)',detail,round(100*fraction));
                if dialog.CancelRequested
                    app.StopRequested = true;
                end
            end
            drawnow limitrate
            if app.StopRequested
                error('SENPAI:Cancelled','Operation cancelled by the user.');
            end
        end

        function finishBusy(app,dialog)
            if ~isempty(dialog) && isvalid(dialog)
                delete(dialog);
            end
            if ~isempty(app.StopButton) && isvalid(app.StopButton)
                app.StopButton.Enable = 'off';
                app.StopButton.Text = 'Stop';
            end
        end

        function writeTiffStack(~,data,filePath)
            if islogical(data)
                data = uint8(data) .* uint8(255);
            elseif isa(data,'double') || isa(data,'single')
                data = uint16(data);
            end
            for zz = 1:size(data,3)
                slice = data(:,:,zz);
                if zz == 1
                    imwrite(slice,filePath,'tif','Compression','none');
                else
                    imwrite(slice,filePath,'tif','WriteMode','append','Compression','none');
                end
            end
        end

        function addLog(app,message)
            stamp = char(datetime('now','Format','HH:mm:ss'));
            line = sprintf('[%s] %s',stamp,message);
            if isempty(app.LogTextArea.Value)
                app.LogTextArea.Value = {line};
            else
                app.LogTextArea.Value = [app.LogTextArea.Value; {line}];
            end
            drawnow limitrate
        end

        function showError(app,ME)
            if strcmp(ME.identifier,'SENPAI:Cancelled')
                addLog(app,'Operation cancelled by the user.');
                return
            end
            addLog(app,['Error: ' ME.message]);
            uialert(app.UIFigure,ME.message,'SENPAI');
        end
    end
end

function label = addLabel(parent,text,row,column)
label = uilabel(parent,'Text',text);
label.Layout.Row = row;
label.Layout.Column = column;
end

function label = sectionLabel(parent,text)
label = uilabel(parent,'Text',text);
label.FontWeight = 'bold';
label.FontSize = 13;
end

function enableScrollable(container)
if isprop(container,'Scrollable')
    container.Scrollable = 'on';
end
end

function values = parseNumericVector(textValue,defaultValue)
if isstring(textValue)
    textValue = char(textValue);
end
cleanText = regexprep(textValue,'[\[\],;]+',' ');
values = sscanf(cleanText,'%f').';
if isempty(values)
    values = defaultValue;
end
end

function pathOut = withFilesep(pathIn)
pathOut = pathIn;
if isempty(pathOut)
    return
end
if pathOut(end) ~= filesep
    pathOut = [pathOut filesep];
end
end
