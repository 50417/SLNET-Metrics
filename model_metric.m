classdef model_metric < handle
    % Gets Metrics
    % Number of blocks
    % Description of Metrics: https://www.mathworks.com/help/slcheck/ref/model-metric-checks.html#buuybtl-1
    % NOTE : Object variables always have to be appended with obj
    properties
        cfg;
        table_name= 'MetricTable_GitHub';
        foreign_table_name = 'GitHub_Simulink_Models';
        conn;
        colnames = {'FILE_ID','Simulink_Model','SubSystem_count','Hierarchy_depth'};


    end
    
    methods
        %Constructor
        function obj = model_metric()
            diary("metrics.log");
            obj.cfg = model_metric_cfg();
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
        function full_path = get_full_path(obj,file)
            full_path = [obj.cfg.source_dir filesep file];
        end
        
        function connect_table(obj)
      
            obj.conn = sqlite(obj.cfg.dbfile,'connect');
            create_metric_table = ['create table IF NOT EXISTS ' obj.table_name ...
                ' (ID INTEGER primary key autoincrement, FILE_ID INTEGER'  ...
                ', Simulink_Model VARCHAR, ' ...
                 'SubSystem_count NUMERIC, Hierarchy_depth NUMERIC,'...
                 'FOREIGN KEY(FILE_ID) REFERENCES ' obj.foreign_table_name...
                 '(id))'];

            exec(obj.conn,create_metric_table);
        end
        
        function output_bol = write_to_database(obj,id,simulink_model_name,subsys_count,depth)%block_count)
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,simulink_model_name,subsys_count,depth});%block_count});
            output_bol= 1;
        end
        
        function results = fetch_file_ids(obj)
            sqlquery = ['SELECT distinct file_id FROM ' obj.table_name];
            results = fetch(obj.conn,sqlquery);
            
            %max(data)
        end
        
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
              fprintf(1, 'Now deleting %s\n', full_folder_name);
              rmdir(full_folder_name,'s');
             end
            
             file_pattern = fullfile(folder, '*.*'); 
            files = dir(file_pattern);%dir(filePattern);
            tf = ismember( {files.name}, {'.', '..'});
            files(tf) = [];
            for k = 1 : length(files)
              base_file_name = files(k).name;
              full_file_name = fullfile(folder, base_file_name);
              fprintf(1, 'Now deleting %s\n', full_file_name);
              delete(full_file_name);
            end
            
        end

            
        function obj = process_all_models_file(obj)
            [list_of_zip_files] = dir(obj.cfg.source_dir); %gives struct with date, name, size info, https://www.mathworks.com/matlabcentral/answers/282562-what-is-the-difference-between-dir-and-ls
            tf = ismember( {list_of_zip_files.name}, {'.', '..'});
            list_of_zip_files(tf) = [];  %remove current and parent directory.
            
            %Fetch All File id from Database to remove redundancy
            file_id_list = cell2mat(obj.fetch_file_ids());
            
           processed_file_count = 1;
           %Loop over each Zip File 
           for cnt = 1 : size(list_of_zip_files)
                    fprintf('Processing #%d :File Id %s\n', processed_file_count,list_of_zip_files(cnt).name);
                    name =strtrim(char(list_of_zip_files(cnt).name));  
                    obj.get_full_path(name);
          
                   
                    tmp_var = strrep(name,'.zip',''); 
                    id = str2num(tmp_var);
         
               
                   if(id == 49592 ||id==45571425 || (id == 152409754 || id ==25870564) )% potential crashes or hangs
                       continue
                   end
                    %Skip if Id already in database 
                    if(~isempty(find(file_id_list==id, 1)))
                       fprintf('File Id %s already processed. Skipping\n',list_of_zip_files(cnt).name);
                       processed_file_count=processed_file_count+1;
                       continue
                    end
                    if (id==51243)
                        disp('here')
                        
                    end
                   %unzip the file TODO: Try CATCH
                   fprintf('Extracting Files\n');
                   list_of_unzipped_files = unzip( obj.get_full_path(list_of_zip_files(cnt).name), obj.cfg.tmp_unzipped_dir);
                  %Assumption Zip file always consists of a single folder .
                  %Adapt later.
                  folder_path= obj.cfg.tmp_unzipped_dir;%char(list_of_unzipped_files(1));
                  %disp(folder_path);
                  % add to the MATLAB search path
                  addpath(genpath(folder_path));
                   
                   
                  fprintf('Searching for slx and mdl file Files\n');
                  for cnt = 1: length(list_of_unzipped_files)
                      path = char(list_of_unzipped_files(cnt));
                      
                       if endsWith(path,"slx") | endsWith(path,"mdl")
                           m= split(path,"/");
                           %m(end); log
                           %disp(list_of_unzipped_files(cnt));
                           fprintf('Found : %s\n',char(m(end)));
                           model_name = strrep(char(m(end)),'.slx','');
                           model_name = strrep(model_name,'.mdl','');
                           fprintf('Calculating Number of blocks of %s\n',model_name);
                           try
                               load_system(model_name)
                               %blk_cnt=(obj.extract_metrics(model_name));%obj.get_total_block_count(model_name));
                                 [subsys_count,depth]=(obj.extract_metrics(model_name));
                               % fprintf("Writing to Database with id = %d Name = %s BlockCount= %d\n",id,char(m(end)),blk_cnt );
                         
                               success = obj.write_to_database(id,char(m(end)),subsys_count,depth);%blk_cnt);
                                catch expection
                               disp(expection);
                           end
                       end
                  end
                  close all hidden;
                 
                rmpath(genpath(folder_path));
                obj.delete_tmp_folder_content(obj.cfg.tmp_unzipped_dir);

                disp(' ')
                processed_file_count=processed_file_count+1;

           end
   
        end
        
        end
    
    methods(Static)
        

        function x = get_total_block_count(model)
            load_system(model)
            [refmodels,modelblock] = find_mdlrefs(model);
           
            % Open dependent models
            for i = 1:length(refmodels)
                load_system(refmodels{i});
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
                disp([refmodels{i} ' has ' num2str(s{i}(1).count) ' blocks'])
            end
            %% Multiply number of blocks, times model count, add to total
            totalBlocks = 0;
            for i = 1:length(refmodels)
                totalBlocks = totalBlocks + s{i}(1).count * mCount(i);
            end
            %disp(' ')
            %disp(['Total blocks: ' num2str(totalBlocks)])   
            x= num2str(totalBlocks);
            close_system(model)
        end
 
        function [subsys_count,subsys_depth] = extract_metrics(model)
                
                load_system(model)
                
        
                %save_system(model,model+_expanded)
                metric_engine = slmetric.Engine();
                %Simulink.BlockDiagram.expandSubsystem(block)
                setAnalysisRoot(metric_engine, 'Root',  model);
                execute(metric_engine)
                % Include referenced models and libraries in the analysis, 
                %     these properties are on by default
                   % metric_engine.ModelReferencesSimulationMode = 'AllModes';
                   % metric_engine.AnalyzeLibraries = 1;
                  res_col = getMetrics(metric_engine,{'mathworks.metrics.SubSystemCount','mathworks.metrics.SubSystemDepth'},'AggregationDepth','all');
                
                metricData ={'MetricID','ComponentPath','Value'};
                cnt = 1;
                for n=1:length(res_col)
                    if res_col(n).Status == 0
                        results = res_col(n).Results;

                        for m=1:length(results)
                            
                            disp(['MetricID: ',results(m).MetricID]);
                            disp(['  ComponentPath: ',results(m).ComponentPath]);
                            disp(['  Value: ',num2str(results(m).Value)]);
                            if strcmp(results(m).ComponentPath,model)
                                if strcmp(results(m).MetricID ,'mathworks.metrics.SubSystemCount')
                                    count = num2str(results(m).Value);
                                elseif strcmp(results(m).MetricID,'mathworks.metrics.SubSystemDepth') 
                                    depth =num2str(results(m).Value);
                                end
                            end
                            metricData{cnt+1,1} = results(m).MetricID;
                            metricData{cnt+1,2} = results(m).ComponentPath;
                            metricData{cnt+1,3} = results(m).Value;
                            cnt = cnt + 1;
                        end
                    else
                        disp(['No results for:',res_col(n).MetricID]);
                    end
                    disp(' ');
                end
                subsys_count = count;
                subsys_depth = depth;
                try
                    close_system(model);
                catch exception
                    disp(exception);
                end
       
        end
    end
    
        
        

end
