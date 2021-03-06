% --- Executes on button press in multinetdect.
function multinetdect_Callback(hObject, eventdata, handles, SingleDetect)
if isempty(handles.audiofiles)
    errordlg('No Audio Selected')
    return
end
if isempty(handles.networkfiles)
    errordlg('No Network Selected')
    return
end
if exist(handles.settings.detectionfolder,'dir')==0
    errordlg('Please Select Output Folder')
    uiwait
    load_detectionFolder_Callback(hObject, eventdata, handles)
    handles = guidata(hObject);  % Get newest version of handles
end

%% Do this if button Multi-Detect is clicked
if ~SingleDetect
    audioselections = listdlg('PromptString','Select Audio Files:','ListSize',[500 300],'ListString',handles.audiofilesnames);
    if isempty(audioselections)
        return
    end
    networkselections = listdlg('PromptString','Select Networks:','ListSize',[500 300],'ListString',handles.networkfilesnames);
    if isempty(audioselections)
        return
    end
    
  
    %% Do this if button Single-Detect is clicked
elseif SingleDetect
    audioselections = get(handles.AudioFilespopup,'Value');
    networkselections = get(handles.neuralnetworkspopup,'Value');
end

Settings = [];
for k=1:length(networkselections)
    prompt = {'Total Analysis Length (Seconds; 0 = Full Duration)','Analysis Chunk Length (Seconds; GPU Dependent)','Overlap (Seconds)','Frequency Cut Off High (kHZ)','Frequency Cut Off Low (kHZ)','Score Threshold (0-1)','Append Date to FileName (1 = yes)'};
    dlg_title = ['Settings for ' handles.networkfiles(networkselections(k)).name];
    num_lines=[1 100]; options.Resize='off'; options.WindowStyle='modal'; options.Interpreter='tex';
    def = handles.settings.detectionSettings;
    current_settings = str2double(inputdlg(prompt,dlg_title,num_lines,def,options));
    
    if isempty(current_settings) % Stop if user presses cancel
        return
    end
    
    Settings = [Settings, current_settings];
    handles.settings.detectionSettings = sprintfc('%g',Settings(:,1))';
end

if isempty(Settings)
    return
end

% Save the new settings
settings = handles.settings;
save([handles.squeakfolder '/settings.mat'],'-struct','settings')
update_folders(hObject, eventdata, handles);
handles = guidata(hObject);  % Get newest version of handles


%% For Each File
for j = 1:length(audioselections)
    CurrentAudioFile = audioselections(j);
    % For Each Network
    Calls = [];
    for k=1:length(networkselections)
        h = waitbar(0,'Loading neural network...');
        
        AudioFile = fullfile(handles.audiofiles(CurrentAudioFile).folder,handles.audiofiles(CurrentAudioFile).name);
        networkname = handles.networkfiles(networkselections(k)).name;
        networkpath = fullfile(handles.networkfiles(networkselections(k)).folder,networkname);
        NeuralNetwork=load(networkpath);%get currently selected option from menu
        close(h);
        
        Calls = [Calls, SqueakDetect(AudioFile,NeuralNetwork,handles.audiofiles(CurrentAudioFile).name,Settings(:,k),j,length(audioselections),networkname,handles.optimization_slider.Value)];

    end
    
    if isempty(Calls)
        fprintf(1,'No Calls found in: %s \n',length(Calls),audioname)
        continue
    end
    
    h = waitbar(1,'Saving...');
    Calls = Automerge_Callback(Calls, [], AudioFile);
    
    %% Save the file
    
    [~,audioname] = fileparts(AudioFile);
    detectiontime=datestr(datetime('now'),'mmm-DD-YYYY HH_MM PM');
    
    % Append date to filename
    if Settings(7)
        fname = fullfile(handles.settings.detectionfolder,[audioname ' ' detectiontime '.mat']);
    else
        fname = fullfile(handles.settings.detectionfolder,[audioname '.mat']);
    end
    
    % Display the number of calls
    fprintf(1,'%d Calls found in: %s \n',length(Calls),audioname)
    
    if ~isempty(Calls)
        save(fname,'Calls','settings','AudioFile','detectiontime','networkpath','-v7.3','-mat');
    end
    
    delete(h)
end
update_folders(hObject, eventdata, handles);
guidata(hObject, handles);
