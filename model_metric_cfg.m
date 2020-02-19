classdef model_metric_cfg < handle
    properties
        % How to use properties : https://www.mathworks.com/help/matlab/matlab_oop/how-to-use-properties.html
        % NOTE : Constant properties val cant be obtained using get methods  
        
        %  Simulink models Zip files  directory to be analyzed
     %directory where the Simulink projects(in zip format) are stored 
       %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'TestCollectingSimulinkModels' filesep  'dir_to_download'] 
       %source_dir = [filesep 'home' filesep 'sls6964xx' filesep 'Downloads' filesep 'SLNet_v1' filesep  'SLNET_GitHub']
       source_dir = [filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'TEST']
       %directory where the sqlite database which contains metadata tables
       %are
        %dbfile = [filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep 'TestCollectingSimulinkModels'  filesep 'xyz.sqlite']
        dbfile = [filesep 'home' filesep 'sls6964xx' filesep 'Downloads' filesep 'SLNet_v1' filesep  'slnet_v1.sqlite']
         
        %New/Existing table Where Simulink model metrics(Block_Count) will be stored
        table_name= 'GitHub_Metric';
   
        %Main table that consists of metadata from the source where the
        %simulink projects is collected from 
        foreign_table_name = 'GitHub_Projects'; 
        %optional
        tmp_unzipped_dir = ''; %Stores UnZipped Files in this directory % Defaults to  current directory with folder tmp/
        %unused right now
        report_dir = ''; %Creates a file and stores results in this directory 
        
    end
    methods
        
    end
    
end