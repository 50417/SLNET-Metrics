classdef model_metric_cfg < handle
    properties
        % How to use properties : https://www.mathworks.com/help/matlab/matlab_oop/how-to-use-properties.html
        % NOTE : Constant properties val cant be obtained using get methods  
        
        %  Simulink models Zip files  directory to be analyzed
        %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'CollectingSimulinkModels' filesep  'MathWorks'] 
        %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'Simulink' ] ;
         %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'CollectingSimulinkModels' filesep  'Simulink'] 
         %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'CollectingSimulinkModels' filesep  'SimulinkMathWorks'] 
        source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'CollectingSimulinkModels' filesep  'SLNET_GitHub'] 
       %models_source_to_analyze = 'Simulink' 
       %source_dir = [ filesep 'home' filesep 'sls6964xx' filesep 'Desktop' filesep 'UtilityProgramNConfigurationFile' filesep  'CollectingSimulinkModels' filesep  'SLNET_MATLABCentral'] 
       
        dbfile = '/home/sls6964xx/Desktop/UtilityProgramNConfigurationFile/CollectingSimulinkModels/slnet_tmp.sqlite'

        tmp_unzipped_dir = ''; %Stores UnZipped Files in this directory % Defaults to  current directory with folder tmp/
        report_dir = ''; %Creates a file and stores results in this directory 
        
    end
    methods
        
    end
    
end