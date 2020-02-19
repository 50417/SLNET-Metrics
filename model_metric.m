classdef model_metric < handle
    % Gets Metrics
    % Number of blocks
    % Description of Metrics: https://www.mathworks.com/help/slcheck/ref/model-metric-checks.html#buuybtl-1
    % NOTE : Object variables always have to be appended with obj
    properties
        cfg;
        table_name;
        foreign_table_name;
        
        conn;
        colnames = {'FILE_ID','Model_Name','is_Lib','SCHK_Block_count','SLDiag_Block_count','SubSystem_count_Top','Agg_SubSystem_count','Hierarchy_depth','LibraryLinked_Count','CComplexity'};
        coltypes = {'INTEGER','VARCHAR','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC'};


    end
    
    methods
        %Constructor
        function obj = model_metric()
            warning on verbose
            obj.WriteLog("open");
            obj.cfg = model_metric_cfg();
            obj.table_name = obj.cfg.table_name;
            obj.foreign_table_name = obj.cfg.foreign_table_name;
            
            %Creates folder to extract zipped filed files in current
            %directory.
            if obj.cfg.tmp_unzipped_dir==""
                obj.cfg.tmp_unzipped_dir = "tmp";
            end
            if(~exist(obj.cfg.tmp_unzipped_dir,'dir'))
                    mkdir(obj.cfg.tmp_unzipped_dir);
            end
            obj.connect_table();
        end
        
      
            %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(obj,Data)
            persistent FID
            % Open the file
            if strcmp(Data, 'open')
              FID = fopen('LogFile.txt', 'w');
              if FID < 0
                 error('Cannot open file');
              end
              return;
            elseif strcmp(Data, 'close')
              fclose(FID);
              FID = -1;
            end
            fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            % Write to the screen at the same time:
            fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
        end
        
        %concatenates file with source directory
        function full_path = get_full_path(obj,file)
            full_path = [obj.cfg.source_dir filesep file];
        end
        
        %creates Table to store model metrics 
        function connect_table(obj)
            obj.conn = sqlite(obj.cfg.dbfile,'connect');
            cols = strcat(obj.colnames(1) ," ",obj.coltypes(1)) ;
            for i=2:length(obj.colnames)
                cols = strcat(cols, ... 
                    ',', ... 
                    obj.colnames(i), " ",obj.coltypes(i) ) ;
            end
           create_metric_table = strcat("create table IF NOT EXISTS ", obj.table_name ...
            ,'( ID INTEGER primary key autoincrement ,', cols  ,", CONSTRAINT FK FOREIGN KEY(FILE_ID) REFERENCES ", obj.foreign_table_name...
                 ,'(id))');
             obj.WriteLog(create_metric_table);
          
           obj.drop_table();
            exec(obj.conn,create_metric_table);
        end
        %Writes to database 
        function output_bol = write_to_database(obj,id,simulink_model_name,isLib,schK_blk_count,block_count,...
                                            subsys_count,agg_subsys_count,depth,linkedcount, cyclo)%block_count)
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,simulink_model_name,isLib,schK_blk_count,block_count,subsys_count,...
                agg_subsys_count,depth,linkedcount,cyclo});%block_count});
            output_bol= 1;
        end
        %gets File Ids from table
        function results = fetch_file_ids(obj)
            sqlquery = ['SELECT distinct file_id FROM ' obj.table_name];
            results = fetch(obj.conn,sqlquery);
            
            %max(data)
        end
        
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE ' obj.table_name];
            exec(obj.conn,sqlquery);
            %max(data)
        end
        
        %Deletes content of obj.cfg.tmp_unzipped_dir such that next
        %project can be analyzed
        function delete_tmp_folder_content(obj,folder)
             % Get a list of all files in the folder
            list = dir(folder);
            % Get a logical vector that tells which is a directory.
            dirFlags = [list.isdir];
            % Extract only those that are directories.
            subFolders = list(dirFlags);
            tf = ismember( {subFolders.name}, {'.', '..'});
            subFolders(tf) = [];  %remove current and parent directory.
        
             for k = 1 : length(subFolders)
              base_folder_name = subFolders(k).name;
              full_folder_name = fullfile(folder, base_folder_name);
              obj.WriteLog(sprintf( 'Now deleting %s\n', full_folder_name));
              rmdir(full_folder_name,'s');
             end
            
             file_pattern = fullfile(folder, '*.*'); 
            files = dir(file_pattern);%dir(filePattern);
            tf = ismember( {files.name}, {'.', '..'});
            files(tf) = [];
            for k = 1 : length(files)
              base_file_name = files(k).name;
              full_file_name = fullfile(folder, base_file_name);
              obj.WriteLog(sprintf( 'Now deleting %s\n', full_file_name));
              delete(full_file_name);
            end
            
        end
        
        %Checks if a models compiles for not
        function compiles = does_model_compile(obj,model)
                %eval(['mex /home/sls6964xx/Desktop/UtilityProgramNConfigurationFile/ModelMetricCollection/tmp/SDF-MATLAB-master/C/src/sfun_ndtable.cpp']);
                eval(['sim',model]);
                obj.WriteLog([model ' compiled Successfully ' ]); 
                %stop_model = eval([model, '([], [], [], ''term'');']); %terminate simulation
                %set_param(gcs, 'SimulationCommand', 'stop');%terminate simulation
                %wait(stop_model);
                %compiles = true;
        end
        
        %Close the model
        function obj= close_the_model(obj,model)
            try
               
               obj.WriteLog(sprintf("Closing %s",model));
         
               close_system(model);
               bdclose(model);
            catch exception
                obj.WriteLog(exception.message);
            end
        end
        %Main function to call to extract model metrics
        function obj = process_all_models_file(obj)
            [list_of_zip_files] = dir(obj.cfg.source_dir); %gives struct with date, name, size info, https://www.mathworks.com/matlabcentral/answers/282562-what-is-the-difference-between-dir-and-ls
            tf = ismember( {list_of_zip_files.name}, {'.', '..'});
            list_of_zip_files(tf) = [];  %remove current and parent directory.
            
            %Fetch All File id from Database to remove redundancy
            file_id_list = cell2mat(obj.fetch_file_ids());
            
           processed_file_count = 1;
           %Loop over each Zip File 
           for cnt = 1 : size(list_of_zip_files)
              
                     name =strtrim(char(list_of_zip_files(cnt).name));  
                    obj.get_full_path(name);
                    log = strcat("Processing #",  num2str(processed_file_count), " :File Id ",list_of_zip_files(cnt).name) ;
                    obj.WriteLog(log);
                   
                    tmp_var = strrep(name,'.zip',''); 
                    id = str2num(tmp_var);
         
               
                    %if(id == 67689 || id == 49592 ||id==45571425 || (id == 152409754 || id ==25870564) )% potential crashes or hangs
                    %   continue
                   %end
                    %Skip if Id already in database 
                    if(~isempty(find(file_id_list==id, 1)))
                       obj.WriteLog(['File Id' list_of_zip_files(cnt).name 'already processed. Skipping']);
                       processed_file_count=processed_file_count+1;
                       continue
                    end
                    if (id==51243)
                        obj.WriteLog('Skipping 51243 File')
                        
                    end
                   %unzip the file TODO: Try CATCH
                   obj.WriteLog('Extracting Files');
                   list_of_unzipped_files = unzip( obj.get_full_path(list_of_zip_files(cnt).name), obj.cfg.tmp_unzipped_dir);
                  %Assumption Zip file always consists of a single folder .
                  %Adapt later.
                  folder_path= obj.cfg.tmp_unzipped_dir;%char(list_of_unzipped_files(1));
                  %disp(folder_path);
                  % add to the MATLAB search path
                  addpath(genpath(folder_path));%genpath doesnot add folder named private or resources in path as it is keyword in R2019a
                   
                   
                  obj.WriteLog('Searching for slx and mdl file Files');
                  for cnt = 1: length(list_of_unzipped_files)
                      path = char(list_of_unzipped_files(cnt));
                      
                       if endsWith(path,"slx") | endsWith(path,"mdl")
                           m= split(path,"/");
                           %m(end); log
                           %disp(list_of_unzipped_files(cnt));
                           obj.WriteLog(sprintf('\nFound : %s',char(m(end))));
                           model_name = strrep(char(m(end)),'.slx','');
                           model_name = strrep(model_name,'.mdl','');
                          
                            
                           try
                               load_system(model_name);
                               obj.WriteLog(sprintf(' %s loaded',model_name));      
                           catch ME
                               obj.WriteLog(sprintf('ERROR loading %s',model_name));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
      
                            try
                               obj.WriteLog(['Calculating Number of blocks of ' model_name]);
                               blk_cnt=obj.get_total_block_count(model_name);
                               obj.WriteLog([' Number of blocks of' model_name ':' num2str( blk_cnt)]);

                             
                               obj.WriteLog(['Calculating other metrics of :' model_name]);
                               [schk_blk_count,agg_subsys_count,subsys_count,depth,liblink_count]=(obj.extract_metrics(model_name));
                               obj.WriteLog(sprintf(" id = %d Name = %s BlockCount= %d AGG_SubCount = %d SubSys_Count=%d Hierarchial_depth=%d LibLInkedCount=%d",...
                                   id,char(m(end)),blk_cnt, agg_subsys_count,subsys_count,depth,liblink_count));
                           catch ME
                               obj.WriteLog(sprintf('ERROR Calculating non compiled metrics for  %s',model_name));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
                               isLib = bdIsLibrary(model_name);
                               if isLib
                                   obj.WriteLog(sprintf('%s is a library. Skipping calculating cyclomatic metric/compile check',model_name));
                                   obj.close_the_model(model_name);
                                   obj.write_to_database(id,char(m(end)),1,schk_blk_count,blk_cnt,...
                                       subsys_count,agg_subsys_count,depth,liblink_count,-1);%blk_cnt);
                           
                                   continue
                               end
                               
                               cyclo_complexity = -1; % If model compile fails. cant check cyclomatic complexity. Hence -1 
                               %{
                               try
                                   
                               
                                   obj.WriteLog(sprintf('Checking if %s compiles?', model_name));
                                   obj.does_model_compile(model_name);
                               catch ME
                                    obj.WriteLog(sprintf('ERROR Compiling %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                        
                               end
                               
                               try
                                   obj.WriteLog(['Calculating cyclomatic complexity of :' model_name]);
                                   cyclo_complexity = obj.extract_cyclomatic_complexity(model_name);
                                   obj.WriteLog(sprintf("Cyclomatic Complexity : %d ",cyclo_complexity));
                               catch ME
                                    obj.WriteLog(sprintf('ERROR Calculating Cyclomatic Complexity %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                               
                               end
                               %}
                               obj.WriteLog(sprintf("Writing to Database"));
                               success = obj.write_to_database(id,char(m(end)),0,schk_blk_count,blk_cnt,subsys_count,agg_subsys_count,depth,liblink_count,cyclo_complexity);%blk_cnt);
                               if success ==1
                                   obj.WriteLog(sprintf("Successful Insert to Database"));
                               end
                           obj.close_the_model(model_name);
                       end
                  end
                 % close all hidden;
                 
                rmpath(genpath(folder_path));
                obj.delete_tmp_folder_content(obj.cfg.tmp_unzipped_dir);

                disp(' ')
                processed_file_count=processed_file_count+1;

           end
   
        end
     
    

        function x = get_total_block_count(obj,model)
            %load_system(model)
            [refmodels,modelblock] = find_mdlrefs(model);
           
            % Open dependent models
            for i = 1:length(refmodels)
                load_system(refmodels{i});
                obj.WriteLog(sprintf(' %s loaded',refmodels{i}));
            end
            %% Count the number of instances
            mCount = zeros(size(refmodels));
            mCount(end) = 1; % Last element is the top model, only one instance
            for i = 1:length(modelblock)
                mod = get_param(modelblock{i},'ModelName');
                mCount = mCount + strcmp(mod,refmodels);
            end
            %%
            %for i = 1:length(mDep)
             %   disp([num2str(mCount(i)) ' instances of' mDep{i}])
            %end
            %disp(' ')

            %% Loop over dependencies, get number of blocks
            s = cell(size(refmodels));
            for i = 1:length(refmodels)
                [t,s{i}] = sldiagnostics(refmodels{i},'CountBlocks');
                obj.WriteLog([refmodels{i} ' has ' num2str(s{i}(1).count) ' blocks'])
            end
            %% Multiply number of blocks, times model count, add to total
            totalBlocks = 0;
            for i = 1:length(refmodels)
                totalBlocks = totalBlocks + s{i}(1).count * mCount(i);
            end
            %disp(' ')
            %disp(['Total blocks: ' num2str(totalBlocks)])   
            x= totalBlocks;
            %close_system(model)
        end
        
        %Calculates model metrics. Models doesnot need to be compilable.
        function [blk_count,agg_sub_count,subsys_count,subsys_depth,liblink_count] = extract_metrics(obj,model)
                
               
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                mData ={'mathworks.metrics.SimulinkBlockCount' ,'mathworks.metrics.SubSystemCount','mathworks.metrics.SubSystemDepth',...
                    'mathworks.metrics.LibraryLinkCount'};
                execute(metric_engine,mData)
                % Include referenced models and libraries in the analysis, 
                %     these properties are on by default
                   % metric_engine.ModelReferencesSimulationMode = 'AllModes';
                   % metric_engine.AnalyzeLibraries = 1;
                  res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                count =0;
                blk_count =0;
                depth=0;
                agg_count=0;
                liblink_count = 0;
                metricData ={'MetricID','ComponentPath','Value'};
                cnt = 1;
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            %disp(['MetricID: ',results(m).MetricID]);
                            %disp(['  ComponentPath: ',results(m).ComponentPath]);
                            %disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.SubSystemCount')
                                    count = results(m).Value;
                                    agg_count =results(m).AggregatedValue;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.SubSystemDepth') 
                                    depth =results(m).Value;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.SimulinkBlockCount') 
                                    blk_count=results(m).AggregatedValue;
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.LibraryLinkCount')%Only for compilable models
                                    liblink_count=results(m).AggregatedValue;
                                end
                            end
                            %metricData{cnt+1,1} = results(m).MetricID;
                            %metricData{cnt+1,2} = results(m).ComponentPath;
                            %metricData{cnt+1,3} = results(m).Value;
                            %cnt = cnt + 1;
                        end
                    else
                        obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
               
                end
                subsys_count = count;
                subsys_depth = depth;
                agg_sub_count = agg_count;
                
          
                
       
        end
        
        %Extract Cyclomatic complexity %MOdels needs to be compilable 
        function [cyclo_metric] = extract_cyclomatic_complexity(obj,model)
                
            
                
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                mData ={'mathworks.metrics.CyclomaticComplexity'};
                try
                    execute(metric_engine,mData);
                catch
                    obj.WriteLog("Error Executing Slmetric API");
                end
                res_col = getMetrics(metric_engine,mData,'AggregationDepth','all');
                
                cyclo_metric = -1 ; %-1 denotes cyclomatic complexit is not computed at all
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            %disp(['MetricID: ',results(m).MetricID]);
                            %disp(['  ComponentPath: ',results(m).ComponentPath]);
                            %disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.CyclomaticComplexity')
                                    cyclo_metric =results(m).AggregatedValue;
                                end
                            end
                        end
                    else
                        
                        obj.WriteLog(['No results for:',res_col(n).MetricID]);
                    end
                    
                end
                
       
        end
    end
    
        
        

end
