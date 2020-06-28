# Replication of the [Paper]
C-corpus replication study refers to replication of this [Paper]
C-corpus sqlite file can be found [here] 
Create an object for model_metric
````
	> model_metric_obj = model_metric();
````
##### Make sure to update the dbfile variable in the model_metric_cfg.m file before  script relevant to SLNET or [Paper]

To get correlation related results
````
	model_metric_obj.correlation_analysis(false,'GitHub','MATC') %For SLNET
	model_metric_obj.correlation_analysis(true,'GitHub','Tutorial','sourceforge','matc','Others') %for [paper] replication study.
````
To get cumulative model metrics per Table
````
    model_metric_obj.total_analyze_metric('<Table Name>',false)%For SLNET
	model_metric_obj.total_analyze_metric('<Table Name>',true)%for C-corpus replication study.
````
To get all the model metrics from all the table/sources combined
````
	model_metric_obj.grand_total_analyze_metric(false)%For SLNET
	model_metric_obj.grand_total_analyze_metric(true)%for C-corpus replication study.
````
To get all other findings.
````	
	model_metric_obj.analyze_metrics(false)%for SLNET
	model_metric_obj.analyze_metrics(true)%for C-corpus replication study.
````
	
[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)
[paper]:http://ranger.uta.edu/~csallner/papers/Chowdhury18Curated.pdf
[here]:https://zenodo.org/record/3912061#.Xvkq3HVKjRa