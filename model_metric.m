classdef model_metric < handle
    % Gets Metrics
    % Number of blocks
    % Description of Metrics: https://www.mathworks.com/help/slcheck/ref/model-metric-checks.html#buuybtl-1
    % NOTE : Object variables always have to be appended with obj
    properties
        cfg;
        table_name;
        foreign_table_name;
        
        blk_info;
        lvl_info;
        
        conn;
        colnames = {'FILE_ID','Model_Name','is_Lib','SCHK_Block_count','SLDiag_Block_count','SubSystem_count_Top',...
            'Agg_SubSystem_count','Hierarchy_depth','LibraryLinked_Count',...,
            'compiles','CComplexity',...
            'Sim_time','Compile_time','Alge_loop_Cnt','target_hw','solver_type','sim_mode'...
            ,'total_ConnH_cnt','total_desc_cnt','ncs_cnt','scc_cnt','unique_sfun_count','sfun_nam_count'...
            ,'mdlref_nam_count','unique_mdl_ref_count'};
        coltypes = {'INTEGER','VARCHAR','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC',...,
            'NUMERIC','NUMERIC','Boolean','NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR','VARCHAR','VARCHAR'...
            ,'NUMERIC','NUMERIC','NUMERIC','NUMERIC','NUMERIC','VARCHAR'...
            ,'VARCHAR','NUMERIC'};
        
        logfilename = strcat('Model_Metric_LogFile',datestr(now, 'dd-mm-yy-HH-MM-SS'),'.txt')
        
       
    end
    
    
    
    methods
        %Constructor
        function obj = model_metric()
            warning on verbose
            obj.cfg = model_metric_cfg();
            obj.WriteLog("open");
            
            obj.table_name = obj.cfg.table_name;
            obj.foreign_table_name = obj.cfg.foreign_table_name;
            
            obj.blk_info = get_block_info(); % extracts block info of top lvl... 
            obj.lvl_info = obtain_non_supported_hierarchial_metrics();
            
            %Creates folder to extract zipped filed files in current
            %directory.
            if obj.cfg.tmp_unzipped_dir==""
                obj.cfg.tmp_unzipped_dir = "workdirtmp";
            end
            if(~exist(obj.cfg.tmp_unzipped_dir,'dir'))
                    mkdir(obj.cfg.tmp_unzipped_dir);
            end
            obj.connect_table();
           
        end
        %Gets simulation time of the model based on the models
        %configuration. If the stopTime of the model is set to Inf, then it
        % sets the simulation time to -1
        %What is simulation Time: https://www.mathworks.com/matlabcentral/answers/163843-simulation-time-and-sampling-time
        function sim_time = get_simulation_time(obj, model) % cs = configuarationSettings of a model
            cs = getActiveConfigSet(model) ;
            startTime = cs.get_param('StartTime');
            stopTime = cs.get_param('StopTime'); %returns a string when time is finite
            try
                startTime = eval(startTime);
                stopTime = eval(stopTime); %making sure that evaluation parts converts to numeric data
                if isfinite(stopTime) && isfinite(startTime) % isfinite() Check whether symbolic array elements are finite
                    
                    assert(isnumeric(startTime) && isnumeric(stopTime));
                    sim_time = stopTime-startTime;
                else
                    sim_time = -1;
                end
            catch
                sim_time = -1;
            end
        end
      
            %Logging purpose
        %Credits: https://www.mathworks.com/matlabcentral/answers/1905-logging-in-a-matlab-script
        function WriteLog(obj,Data)
            global FID % https://www.mathworks.com/help/matlab/ref/global.html %https://www.mathworks.com/help/matlab/ref/persistent.html Local to functions but values are persisted between calls.
            if isempty(FID) & ~strcmp(Data,'open')
                
                 FID = fopen(['logs' filesep obj.logfilename], 'a+');
            end
            % Open the file
            if strcmp(Data, 'open')
                mkdir('logs');
              FID = fopen(['logs' filesep obj.logfilename], 'a+');
              if FID < 0
                 error('Cannot open file');
              end
              return;
            elseif strcmp(Data, 'close')
              fclose(FID);
              FID = -1;
            end
            try
                fprintf(FID, '%s: %s\n',datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            catch ME
                ME
            end
            % Write to the screen at the same time:
            if obj.cfg.DEBUG
                fprintf('%s: %s\n', datestr(now, 'dd/mm/yy-HH:MM:SS'), Data);
            end
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
            ,'( ID INTEGER primary key autoincrement ,', cols  ,...
            ", CONSTRAINT FK FOREIGN KEY(FILE_ID) REFERENCES ", obj.foreign_table_name...
                 ,'(id) ,'...
                ,'CONSTRAINT UPair  UNIQUE(FILE_ID, Model_Name) )');
            
            if obj.cfg.DROP_TABLES
                obj.WriteLog(sprintf("Dropping %s",obj.table_name))
                obj.drop_table();
                obj.WriteLog(sprintf("Dropped %s",obj.table_name))
            end
             obj.WriteLog(create_metric_table);
            exec(obj.conn,create_metric_table);
        end
        %Writes to database 
        function output_bol = write_to_database(obj,id,simulink_model_name,isLib,schK_blk_count,block_count,...
                                            subsys_count,agg_subsys_count,depth,linkedcount,compiles, cyclo,...
                                            sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode,...
                                            total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,...
                                            sfun_reused_key_val,...
                                            modelrefMap_reused_val,unique_mdl_ref_count)%block_count)
            insert(obj.conn,obj.table_name,obj.colnames, ...
                {id,simulink_model_name,isLib,schK_blk_count,block_count,subsys_count,...
                agg_subsys_count,depth,linkedcount,compiles,cyclo,...
                sim_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                ,total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,...
                sfun_reused_key_val...
                ,modelrefMap_reused_val,unique_mdl_ref_count});%block_count});
            output_bol= 1;
        end
        %gets File Ids and model name from table
        function results = fetch_file_ids_model_name(obj)
            sqlquery = ['SELECT file_id,model_name FROM ' obj.table_name];
            results = fetch(obj.conn,sqlquery);
            
            %max(data)
        end
        
        %Construct matrix that concatenates 'file_id'+'model_name' to
        %avoid recalculating the metrics
        function unique_id_mdl = get_database_content(obj)
            
            file_id_n_model = obj.fetch_file_ids_model_name();
            unique_id_mdl = string.empty(0,length(file_id_n_model));
            for i = 1 : length(file_id_n_model)
                %https://www.mathworks.com/matlabcentral/answers/350385-getting-integer-out-of-cell   
                unique_id_mdl(i) = strcat(num2str(file_id_n_model{i,1}),file_id_n_model(i,2));
            
            end
         
        end
        
        
        %drop table Striclty for debugging purposes
        function drop_table(obj)
            %Strictly for debugginf purpose only
            sqlquery = ['DROP TABLE IF EXISTS ' obj.table_name];
            exec(obj.conn,sqlquery);
            %max(data)
        end
        

        
        %Deletes content of obj.cfg.tmp_unzipped_dir such that next
        %project can be analyzed
        function delete_tmp_folder_content(obj,folder)
            %{
            %Get a list of all files in the folder
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
            %}
            %fclose('all'); %Some files are opened by the models
            global FID;
            arrayfun(@fclose, setdiff(fopen('all'), FID));
            if exist('slprj', 'dir')
                rmdir('slprj','s');
            end
            if ispc
                rmdir(obj.cfg.tmp_unzipped_dir,'s');
                %system(strcat('rmdir /S /Q ' ," ",folder));
            elseif isunix
                system(strcat('rmdir -p'," ",folder))
            else 
                 rmdir(folder,'s');%https://www.mathworks.com/matlabcentral/answers/21413-error-using-rmdir
            end
            obj.WriteLog("open");
            rehash;
            java.lang.Thread.sleep(5);
            mkdir(folder);
            obj.cleanup();
            
        end
        
        %returns number of algebraic loop in the model. 
        %What is algebraic Loops :
        %https://www.mathworks.com/help/simulink/ug/algebraic-loops.html  https://www.mathworks.com/matlabcentral/answers/95310-what-are-algebraic-loops-in-simulink-and-how-do-i-solve-them
        function num_alge_loop = get_number_of_algebraic_loops(obj,model)
            alge_loops = Simulink.BlockDiagram.getAlgebraicLoops(model);
            num_alge_loop  = numel(alge_loops);            
        end
        

       
        %Checks if a models compiles for not
        function compiles = does_model_compile(obj,model)
                %eval(['mex /home/sls6964xx/Desktop/UtilityProgramNConfigurationFile/ModelMetricCollection/tmp/SDF-MATLAB-master/C/src/sfun_ndtable.cpp']);
               %'com.mathworks.mde.cmdwin.CmdWinMLIF.getInstance().processKeyFromC(2,67,''C'')'

                %obj.timeout = timer('TimerFcn'," ME = MException('Timeout:TimeExceeded','Time Exceeded While Compiling');throw(ME);",'StartDelay',1);
                %start(obj.timeout);
                eval([model, '([], [], [], ''compile'');'])
                obj.WriteLog([model ' compiled Successfully ' ]); 
                
               % stop(obj.timeout);
                %delete(obj.timeout);
                compiles = 1;
        end
        
        %Close the model
        % Close the model https://www.mathworks.com/matlabcentral/answers/173164-why-the-models-stays-in-paused-after-initialisation-state
        function obj= close_the_model(obj,model)
            try
               
               obj.WriteLog(sprintf("Closing %s",model));
         
               close_system(model);
               bdclose(model);
            catch exception
               
                obj.WriteLog(exception.message);
                obj.WriteLog("Trying Again");
                if (strcmp(exception.identifier ,'Simulink:Commands:InvModelDirty' ))
                    obj.WriteLog("Force Closing");
                    bdclose(model);
                    return;
                end
                %eval([model '([],[],[],''sizes'')']);
                eval([model '([],[],[],''term'')']);
                obj.close_the_model(model);
            end
        end
        
        function [target_hw,solver_type,sim_mode]=get_solver_hw_simmode(obj,model)
            cs = getActiveConfigSet(model);
            target_hw = cs.get_param('TargetHWDeviceType');


            solver_type = get_param(model,'SolverType');
            if isempty(solver_type)
                solver_type = 'NA';
            end


            sim_mode = get_param(model, 'SimulationMode');
        end
        
        %Main function to call to extract model metrics
        function obj = process_all_models_file(obj)
            [list_of_zip_files] = dir(obj.cfg.source_dir); %gives struct with date, name, size info, https://www.mathworks.com/matlabcentral/answers/282562-what-is-the-difference-between-dir-and-ls
            tf = ismember( {list_of_zip_files.name}, {'.', '..'});
            list_of_zip_files(tf) = [];  %remove current and parent directory.
            
            %Fetch All File id and model_name from Database to remove redundancy
                    
            file_id_mdl_array = obj.get_database_content(); 
            
           processed_file_count = 1;
           %Loop over each Zip File 
           for cnt = 1 : size(list_of_zip_files)
              
              

                     name =strtrim(char(list_of_zip_files(cnt).name));  
                    obj.get_full_path(name);
                    log = strcat("Processing #",  num2str(processed_file_count), " :File Id ",list_of_zip_files(cnt).name) ;
                    obj.WriteLog(log);
                   
                    tmp_var = strrep(name,'.zip',''); 
                    id = str2num(tmp_var);
         
                    %id==70131 || kr_billiards_debug crashes MATLAB when
                    %compiles in windows only MATLAB 2018b MATLAB 2019b
                   %id == 67689 cant find count becuase referenced model has
                   %protected component.
                   %id == 152409754 hangs because requires select folder for installation input
                
                   %id ===24437619 %suspious56873326
                   %id == 25870564 no license | Not in SLNet 
                   % id==45571425 No license | NOt in SLNet
                   % Cocoteam/benchmark
                   %id == 73878  % Requires user input
                   %id ==722 % crashes on Windowns Matlab 2019b in windows Only while SimCheck extract metrics 2018b not
                   %checked
                   %id==51243 Changes directory while analyzing. 
                   %id == 51705 % Requires user input: Enter morse code. 
                   if ispc
                        if (id==70131 || id==51243 || id ==24437619 || id==198236388 || id == 124448612 ) % potential crashes or hangs
                            continue
                        end
                   end
                   if (id==51705) %  % Requires user input: Enter morse code. 
                            continue
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
                      file_path = char(list_of_unzipped_files(cnt));
                      
                       if endsWith(file_path,"slx") | endsWith(file_path,"mdl")
                           m= split(file_path,filesep);
                           
                           %m(end); log
                           %disp(list_of_unzipped_files(cnt));
                           obj.WriteLog(sprintf('\nFound : %s',char(m(end))));
                           
                          
                           model_name = strrep(char(m(end)),'.slx','');
                           model_name = strrep(model_name,'.mdl','');
                          %Skip if Id and model name already in database 
                            if(~isempty(find(file_id_mdl_array==strcat(num2str(id),char(m(end))), 1)))
                               obj.WriteLog(sprintf('File Id %d %s already processed. Skipping', id, char(m(end)) ));
                                continue
                            end
                            
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

                           if ~isempty(sltest.harness.find(model_name,'SearchDepth',15))
                                obj.WriteLog(sprintf('File Id %d : model : %s has %d test harness',...
                                    id, char(m(end))  ,length(sltest.harness.find(model_name,'SearchDepth',15))));
                            end
                           
                            try
                               %sLDIAGNOSTIC BLOCK COUNT .. BASED ON https://blogs.mathworks.com/simulink/2009/08/11/how-many-blocks-are-in-that-model/
                               obj.WriteLog(['Calculating Number of blocks (BASED ON sLDIAGNOSTIC TOOL) of ' model_name]);
                               blk_cnt=obj.get_total_block_count(model_name);
                               obj.WriteLog([' Number of blocks(BASED ON sLDIAGNOSTIC TOOL) of' model_name ':' num2str( blk_cnt)]);

                              obj.WriteLog(['Calculating  metrics  based on Simulink Check API of :' model_name]);
                               [schk_blk_count,agg_subsys_count,subsys_count,depth,liblink_count]=(obj.extract_metrics(model_name));
                               obj.WriteLog(sprintf(" id = %d Name = %s BlockCount= %d AGG_SubCount = %d SubSys_Count=%d Hierarchial_depth=%d LibLInkedCount=%d",...
                                   id,char(m(end)),blk_cnt, agg_subsys_count,subsys_count,depth,liblink_count));
                               
                               
                               obj.WriteLog(['Populating level wise | hierarchial info of ' model_name]);
                               [total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count,sfun_reused_key_val,blk_type_count,modelrefMap_reused_val,unique_mdl_ref_count] = obj.lvl_info.populate_hierarchy_info(id, char(m(end)),depth,schk_blk_count);
                               obj.WriteLog([' level wise Info Updated of' model_name]);
                               obj.WriteLog(sprintf("Lines= %d Descendant count = %d NCS count=%d Unique S fun count=%d",...
                               total_lines_cnt,total_descendant_count,ncs_count,unique_sfun_count));
                                
                                obj.WriteLog(['Populating block info of ' model_name]); 
                               %[t,blk_type_count]=
                               %sldiagnostics(model_name,'CountBlocks');
                               %Only gives top level block types
                               obj.blk_info.populate_block_info(id,char(m(end)),blk_type_count);
                               obj.WriteLog([' Block Info Updated of' model_name]);
                              
                           
                              
                           catch ME
                             
                               obj.WriteLog(sprintf('ERROR Calculating non compiled metrics for  %s',model_name));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                continue;
                               %rmpath(genpath(folder_path));
                           end
                               isLib = bdIsLibrary(model_name);% Generally Library are precompiled:  https://www.mathworks.com/help/simulink/ug/creating-block-libraries.html
                               if isLib
                                   obj.WriteLog(sprintf('%s is a library. Skipping calculating cyclomatic metric/compile check',model_name));
                                   obj.close_the_model(model_name);
                                   try
                                   obj.write_to_database(id,char(m(end)),1,schk_blk_count,blk_cnt,...
                                       subsys_count,agg_subsys_count,depth,liblink_count,-1,-1 ...
                                   ,-1,-1,-1,'N/A','N/A','N/A'...
                                            ,-1,-1,-1,-1,-1 ...
                                            ,'N/A','N/A',-1);%blk_cnt);
                                   catch ME
                                       obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                     obj.WriteLog(['ERROR MSG : ' ME.message]);
                                   end
                                   continue
                               end
                               
                               cyclo_complexity = -1; % If model compile fails. cant check cyclomatic complexity. Hence -1 
                               compiles = 0;
                               compile_time = -1;
                               num_alge_loop = 0;
                               try                               
                                  obj.WriteLog(sprintf('Checking if %s compiles?', model_name));
                                   timeout = timer('TimerFcn',' com.mathworks.mde.cmdwin.CmdWinMLIF.getInstance().processKeyFromC(2,67,''C'')','StartDelay',120);
                                    start(timeout);
                                   compiles = obj.does_model_compile(model_name);
                                    stop(timeout);
                                    delete(timeout);
                                    obj.close_the_model(model_name);
                               catch ME
                                    %stop(obj.timeout);
                                    delete(timeout); 
                                   
                                    obj.WriteLog(sprintf('ERROR Compiling %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                        
                               end
                               if compiles
                                   try
                                        [~, sRpt] = sldiagnostics(model_name, 'CompileStats');
                                        compile_time = sum([sRpt.Statistics(:).WallClockTime]);
                                        obj.WriteLog(sprintf(' Compile Time of  %s : %d',model_name,compile_time)); 
                                        
                                        obj.WriteLog(sprintf(' Checking ALgebraic Loop of  %s',model_name)); 
                                        
                                        num_alge_loop = obj.get_number_of_algebraic_loops(model_name);
                                        obj.WriteLog(sprintf(' Algebraic Loop of  %s : %d',model_name,num_alge_loop)); 
                                        
                                   catch
                                       ME
                                        obj.WriteLog(sprintf('ERROR calculating compile time or algebraic loop of  %s',model_name)); 
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
                               end
                               %}
                               %if (compiles)
                                   
                                    try
                                       obj.WriteLog(['Calculating Simulation Time of the model :' model_name]);
                                       simulation_time = obj.get_simulation_time(model_name);
                                       obj.WriteLog(sprintf("Simulation Time  : %d (-1 means cant calculate due to Inf stoptime) ",simulation_time));
                                   catch ME
                                        obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        obj.WriteLog(['ERROR MSG : ' ME.message]);

                                    end
                                    target_hw = '';
                                    solver_type = '';
                                    sim_mode = '';
                                     try
                                       obj.WriteLog(['Calculating Target Hardware | Simulation Mode | Solver of ' model_name]);
                                       [target_hw,solver_type,sim_mode] = obj.get_solver_hw_simmode(model_name);
                                       obj.WriteLog(sprintf("Target HW : %s Solver Type : %s Sim_mode : %s ",target_hw,solver_type,sim_mode));
                                   catch ME
                                        obj.WriteLog(sprintf('ERROR Calculating Simulation Time of %s',model_name));                    
                                        obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                        obj.WriteLog(['ERROR MSG : ' ME.message]);

                                     end
                                  
                                 
                                   
                                 
                                   
                                   
                               %end
                               obj.WriteLog(sprintf("Writing to Database"));
                               try
                                    success = obj.write_to_database(id,char(m(end)),0,schk_blk_count,blk_cnt,subsys_count,...
                                            agg_subsys_count,depth,liblink_count,compiles,cyclo_complexity...
                                            ,simulation_time,compile_time,num_alge_loop,target_hw,solver_type,sim_mode...
                                            ,total_lines_cnt,total_descendant_count,ncs_count,scc_count,unique_sfun_count...
                                            ,sfun_reused_key_val...
                                            ,modelrefMap_reused_val,unique_mdl_ref_count);%blk_cnt);
                               catch ME
                                    obj.WriteLog(sprintf('ERROR Inserting to Database %s',model_name));                    
                                    obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                    obj.WriteLog(['ERROR MSG : ' ME.message]);
                               end
                               if success ==1
                                   obj.WriteLog(sprintf("Successful Insert to Database"));
                                   success = 0;
                               end
                           obj.close_the_model(model_name);
                       end
                  end
                 % close all hidden;
                 
                rmpath(genpath(folder_path));
                try
                    obj.delete_tmp_folder_content(obj.cfg.tmp_unzipped_dir);
                catch ME
                    obj.WriteLog(sprintf('ERROR deleting'));                    
                                obj.WriteLog(['ERROR ID : ' ME.identifier]);
                                obj.WriteLog(['ERROR MSG : ' ME.message]);
                                
                end
                                disp(' ')
                            
                processed_file_count=processed_file_count+1;

           end
           obj.WriteLog("Cleaning up Tmp files")
           obj.cleanup()
   
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
        
        %to clean up files MATLAB generates while processing
        function cleanup(obj)
            extensions = {'slxc','c','mat','wav','bmp','log'...
               'tlc','mexw64'}; % cell arrAY.. Add file extesiion 
            for i = 1 :  length(extensions)
                delete( strcat("*.",extensions(i)));
            end
            
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
        

        % correlation analysis : Cyclomatic complexity with other metrics 
        function correlation_analysis(obj)
            format short;
    
            sqlquery = ['select * from(',... 
                ' select CComplexity,compile_time, Schk_block_count,total_connH_cnt, hierarchy_Depth,total_desc_cnt,ncs_cnt,scc_cnt from github_Metric ' ,...
                ' where is_Lib =0  and compiles = 1 and CComplexity!=-1 ',...
                ' union',...
                ' select CComplexity,compile_time, Schk_block_count,total_connH_cnt, hierarchy_Depth,total_desc_cnt,ncs_cnt,scc_cnt from Matc_Metric  ',...
                ' where is_Lib =0  and compiles = 1 and CComplexity!=-1 )',...
                ' order by CComplexity'];
            results = fetch(obj.conn,sqlquery);
            results = cellfun(@(x)double(x),results);
            %{
            try
                for i=1:6
                    single_metric = sort(results(:,i));
                    normalized_metric = (single_metric - mean(single_metric))/std(single_metric) ;
                    disp(kstest( normalized_metric ));
                end
            catch e
                fprintf('Err in normality test: \n');
                return;
            end
              %}
            %metrics = cell2mat(results)
            [rho,pval] = corrcoef(results);
            Cc_corr_with ={'compile_time', 'block_count','connection', 'max depth','child representing blocks','NCS','SCC'};
            for i = 2:8
                 obj.WriteLog(sprintf('%s\n',Cc_corr_with{i-1}));
                [tau, kpal] = corr(results(:,1),results(:,i), 'type', 'Kendall', 'rows', 'pairwise');
                [Sm, Sp] = corr(results(:,1),results(:,i), 'type', 'Spearman', 'rows', 'pairwise');
                fprintf('Kendall : %2.4f %2.4f \n',tau,kpal);
                fprintf('Spearman : %2.4f %2.4f \n',Sm, Sp);
            end
           % [tau, kpal] = corr(results, 'type', 'Kendall', 'rows', 'pairwise');
            
    
        end
        
        function median_val = median(obj, list )
            %list is sorted based on last columns
                [~,idx] = sort(list(:,length(list(1,:))));
                sorted_results = list(idx,:);
                median_val = (length(sorted_results) + 1)/2;
                
                if(mod(median_val,2)==0)
                    median_val = sorted_results(median_val,length(list(1,:)));
                else
                    median_val = sorted_results(ceil(median_val),length(list(1,:)))+ sorted_results(floor(median_val),length(list(1,:)))/2;
                end
        
        end
        function analyze_metrics(obj)
            format long;
            %total models analyzed : 
            total_analyzed_mdl_query = ['select count(*) from',...
                                ' (select * from github_metric where  is_lib=0',...
                                 '   union',...
                                  '  select * from  matc_metric where  is_lib=0',...
                                   ' )'];
            total_models_analyzed =  fetch(obj.conn,total_analyzed_mdl_query);
            %Fetching from db 
            query_hierar_median_blk_cnt =['select depth,block_count from ',...
                '(select * from GitHub_Subsys_Info where (file_id,Model_Name)',...
                ' not in (select file_id,Model_Name from GitHub_Metric where is_lib=1)',...
                ' union',...
                ' select * from MATC_Subsys_Info where (file_id,Model_Name)', ...
                'not in (select file_id,Model_Name from matc_Metric where is_lib=1))'];
            obj.WriteLog(sprintf("Fetching   block counts of each subsystem per hierarchial lvl with query \n %s",query_hierar_median_blk_cnt));
            results = fetch(obj.conn,query_hierar_median_blk_cnt);
            results = cellfun(@(x)double(x),results);
            obj.WriteLog(sprintf("Fetched   %d results ",length(results)));
            max_depth = max(results(:,1));
            obj.WriteLog(sprintf("Max Depth =  %d  ",max_depth-1));%lvl 1 = lvl 0 as the subsystem is in lvl 0 and its corresponding blocks are in lvl 1 .
            %results_per_hierar = cell(max_depth,1);
            max_val = 0; % maximum number of blocks among all hierarchy lvl . 
            for i = 1:max_depth
                %results_per_hierar(i,1) = {results(results(:,1)==i,:)};
                tmp_results_of_hierar_i = results(results(:,1)==i,:);
                val = obj.median(tmp_results_of_hierar_i);
                 obj.WriteLog(sprintf("Depth =  %d Median number of blocks per subsystem = %d  ",i-1,val));%lvl 1 = lvl 0 as the subsystem is in lvl 0 and its corresponding blocks are in lvl 1 .
     
                if(val>max_val)
                    max_val = round(val);
                end
            end
            
            query_matc_models = 'select avg(SCHK_Block_count) from MATC_Metric where is_lib=0';
            obj.WriteLog(sprintf("Fetching  Avg block counts in Matlab Central Models"));
            avg_block = fetch(obj.conn,query_matc_models);
            
            models_over_1000_blk_query = ['select sum(c) from(',...
            ' select count(*) as c from github_metric where SCHK_block_count>1000 and is_lib=0',...
            ' union',...
            ' select count(*) as c from  matc_metric where SCHK_block_count>1000 and is_lib=0',...
            ' )'
            ];
            models_over_1000blk_cnt = fetch(obj.conn,models_over_1000_blk_query);
            
            %model referencing 
            models_use_mdlref_query = ['select mdlref_nam_count from',...
                                ' (select * from github_metric where unique_mdl_ref_count>0 and  is_lib=0',...
                                 '   union',...
                                  '  select * from  matc_metric where unique_mdl_ref_count>0 and is_lib=0',...
                                   ' )'];
            models_use_mdlref = fetch(obj.conn,models_use_mdlref_query);
            mdl_ref_reuse_count = 0 ;
            for j = 1 : length(models_use_mdlref)
                mdl_ref_list = split(models_use_mdlref{j},',');
                for k = 2 : length(mdl_ref_list) % 2 because there is always 0 char array at the beginning index
                    tmp = split(mdl_ref_list{k},'_');
                    mdl_ref_count = str2double(tmp{length(tmp)});
                    if(mdl_ref_count>1)
                       
                        mdl_ref_reuse_count = mdl_ref_reuse_count+1; 
                        break;
                    end
                end
            end
            %sfun_use_query
            models_use_sfun_query = ['select sfun_nam_count from',...
                                ' (select * from github_metric where unique_sfun_count>0 and  is_lib=0',...
                                 '   union',...
                                  '  select * from  matc_metric where unique_sfun_count>0 and is_lib=0',...
                                   ' )'];
            models_use_sfun = fetch(obj.conn,models_use_sfun_query);

            %sfun_reuse_vector = [];
            sfun_reuse_count = 0 ;
            for j = 1 : length(models_use_sfun)
                sfun_list = split(models_use_sfun{j},',');
                for k = 2 : length(sfun_list) % 2 because there is always 0 char array at the beginning index
                    tmp = split(sfun_list{k},'_');
                    sfun_count = str2double(tmp{length(tmp)});
                    if(sfun_count>1)
                     %  sfun_reuse_vector(end+1) = 1;
                        sfun_reuse_count = sfun_reuse_count+1; 
                        break;
                    
                    end
                    
                end
                %if sfun_count<=1
                 %        sfun_reuse_vector(end+1) = 0;
                 %   end
            end
            %median_sfun= obj.median(transpose(sfun_reuse_vector));
            
            
            most_frequentlused_blocks_query_git = ['select BLK_TYPE,sum(count)  as c from GitHub_Block_Info group by BLK_TYPE order by  c desc'];
            
            most_frequentlused_blocks_query_matc = ['select  BLK_TYPE,sum(count)  as c from matc_Block_Info  group by BLK_TYPE order by  c desc'];
            
            most_frequentlused_blocks_git = fetch(obj.conn,most_frequentlused_blocks_query_git);
            most_frequentlused_blocks_matc = fetch(obj.conn,most_frequentlused_blocks_query_matc);
            
            %15 most frequently used block besides top 3 . 
            most_15_freq_used_blks_git = most_frequentlused_blocks_git{4};
            most_15_freq_used_blks_matc = most_frequentlused_blocks_matc{4};
            
            for i = 5 : 18
                most_15_freq_used_blks_git = strcat(most_15_freq_used_blks_git,",",most_frequentlused_blocks_git{i});
                most_15_freq_used_blks_matc = strcat(most_15_freq_used_blks_matc,",",most_frequentlused_blocks_matc{i});
            end
            obj.WriteLog(sprintf("==============RESULTS=================="));
            obj.WriteLog(sprintf("Total Models analyzed : %d ",total_models_analyzed{1}));
            
            obj.WriteLog(sprintf("Medium number of block per hierarchial lvl does not exceed  %d (vs 17)",max_val));
            obj.WriteLog(sprintf("Average  number of block in Matlab Central models: %2.2f (which is %d times smaller than industrial models(752 models))",...
                avg_block{1},(752/avg_block{1})));
            obj.WriteLog(sprintf("Number of models with over 1000 blocks : %d (vs 93 models)",models_over_1000blk_cnt{1}));
            obj.WriteLog(sprintf("Number of models that use model referencing : %d\n Number of models that reused referenced models : %d (vs 1 models) ",length(models_use_mdlref),mdl_ref_reuse_count));
            obj.WriteLog(sprintf("Number of models that use S-functions : %d\n Number of models that reused sfun : %d\n Fraction of model reusing sfun = %d",length(models_use_sfun),sfun_reuse_count,sfun_reuse_count/length(models_use_sfun)));
            obj.WriteLog(sprintf("Most Frequently used blocks in GitHub projects : \n %s ",most_15_freq_used_blks_git));
            obj.WriteLog(sprintf("Most Frequently used blocks in Matlab Central projects : \n %s ",most_15_freq_used_blks_matc));
        end
        
        function res = total_analyze_metric(obj,table)
            blk_connec_query = ['select sum(SLDiag_Block_count),sum(SCHK_block_count),sum(total_ConnH_cnt) from ', table ,' where is_Lib = 0'];
            solver_type_query = ['select solver_type,count(solver_type) from ', table, ' where is_Lib = 0 group by solver_type'];
            sim_mode_query = ['select sim_mode,count(sim_mode) from ',table,' where is_Lib = 0 group by sim_mode'];
            total_analyzedmdl_query = ['select count(*) from ', table,' where is_Lib = 0 '];
            total_model_compiles = ['select count(*) from ',table,' where is_Lib = 0  and compiles = 1'];
            total_hierarchial_model_query = ['select count(*) from ',table, ' where is_Lib = 0  and Hierarchy_depth>0'];
            
            obj.WriteLog(sprintf("Fetching Total Analyzed model of %s table with query \n %s",table,total_analyzedmdl_query));
            total_analyzedmdl = fetch(obj.conn, total_analyzedmdl_query);
            
            res.analyzedmdl = total_analyzedmdl{1};
            
            obj.WriteLog(sprintf("Fetching Total readily compilable model of %s table with query \n %s",table,total_model_compiles));
            total_model_compiles = fetch(obj.conn, total_model_compiles);
            
            res.mdl_compiles = total_model_compiles{1};
            
            obj.WriteLog(sprintf("Fetching Total hierarchial model of %s table with query \n %s",table,total_hierarchial_model_query));
            total_hierarchial_model = fetch(obj.conn, total_hierarchial_model_query);
            
            res.total_hierar = total_hierarchial_model{1};
            
            obj.WriteLog(sprintf("Fetching Total counts of %s table with query \n %s",table,blk_connec_query));
            blk_connec_cnt = fetch(obj.conn, blk_connec_query);
            
            res.sldiag = blk_connec_cnt{1};
            res.slchk = blk_connec_cnt{2};
            res.connec = blk_connec_cnt{3};
            
            obj.WriteLog(sprintf("Fetching solver type of %s table with query \n %s",table,solver_type_query));
            solver_type = fetch(obj.conn, solver_type_query);
            res.other_solver = 0 ;
            for i = 1 : length(solver_type)
                if(strcmp(solver_type{i,1},'Fixed-step'))
                    res.fix = solver_type{i,2};
                elseif (strcmp(solver_type{i,1},'Variable-step'))
                     res.var = solver_type{i,2};
                else 
                    res.other_solver = res.other_solver + solver_type{i,2};
                end
            end
            
            
            obj.WriteLog(sprintf("Fetching simulation mode of %s table with query \n %s",table,sim_mode_query));
            sim_mode = fetch(obj.conn, sim_mode_query);
            res.other_sim = 0 ;
            for i = 1 : length(sim_mode)
                switch sim_mode{i,1}
                    case 'accelerator'
                        res.acc = sim_mode{i,2};
                    case 'external'
                        res.ext = sim_mode{i,2};
                    case 'normal'
                        res.normal = sim_mode{i,2};
                    case 'processor-in-the-loop (pil)'
                        res.pil = sim_mode{i,2};
                    case 'rapid-accelerator'
                        res.rpdacc = sim_mode{i,2};
                    otherwise
                        res.other_sim = res.other_sim + sim_mode{i,2};
                end
            end
            

        
        end
        function grand_total_analyze_metric(obj)
            github = obj.total_analyze_metric('Github_metric');
            matc = obj.total_analyze_metric('MATC_metric');
            fn = fieldnames(matc)
            for i = 1 : length(fn)
                res.(fn{i}) = github.(fn{i}) + matc.(fn{i});
            end
            res
         end

    end
    
        
        

end
