### SNAKEFILE GENETIC DIAGNOSIS PIPELINE
import os
import re
from config_parser import ConfigHelper

## ADD tmp/ DIR
tmpdir = config["ROOT"] + '/' + config["DATASET_NAME"] + '/tmp'
config["tmpdir"] = tmpdir
if not os.path.exists(tmpdir):
    os.makedirs(tmpdir)


### Write one config file for every subworkflow with a diferent index name
import oyaml
with open(tmpdir + '/config_aberrant_expression.yaml', 'w') as yaml_file:
    config_ae = config.copy()
    oyaml.dump(config_ae, yaml_file, default_flow_style=False)
    
with open(tmpdir + '/config_aberrant_splicing.yaml', 'w') as yaml_file:
    config_as = config.copy()
    oyaml.dump(config_as, yaml_file, default_flow_style=False)
    
with open(tmpdir + '/config_mae.yaml', 'w') as yaml_file:
    config_mae = config.copy()
    oyaml.dump(config_mae, yaml_file, default_flow_style=False)    


#print("In Snakefile from genetic_diagnosis",config)
parser = ConfigHelper(config)
config = parser.config # needed if you dont provide the wbuild.yaml as configfile
include: os.getcwd() + "/.wBuild/wBuild.snakefile" 

htmlOutputPath = config["htmlOutputPath"]

# 1 aberrant Expression
subworkflow aberrantExp:
    workdir:
        "submodules/aberrant-expression-pipeline"
    snakefile:
        "submodules/aberrant-expression-pipeline/Snakefile"
    configfile:
        tmpdir + "/config_aberrant_expression.yaml"

# 2 aberrant Splicing
subworkflow aberrantSplicing:
    workdir:
        "submodules/aberrant-splicing-pipeline"
    snakefile:
        "submodules/aberrant-splicing-pipeline/Snakefile"
    configfile:
        tmpdir + "/config_aberrant_splicing.yaml"

# 3 mae
subworkflow mae:
    workdir:
        "submodules/mae-pipeline"
    snakefile:
        "submodules/mae-pipeline/Snakefile"
    configfile:
        tmpdir + "/config_mae.yaml"


rule all:
    input: 
        aberrantExp(tmpdir + "/aberrant_expression.done"),
#       aberrantSplicing(tmpdir + "/aberrant_splicing.done"),
        mae(tmpdir + "/mae.done"),
	      tmpdir + "/gdp_overview.done" 
    output:
        touch(tmpdir + "/gdp_all.done")

######## Do not delete this!!!
rule aberrant_expression:
    input:
        aberrantExp(tmpdir + "/aberrant_expression.done")
    output:
        touch(tmpdir + "/gdp_aberrant_expression.done")
        
rule aberrant_splicing:
    input:
        aberrantSplicing(tmpdir + "/aberrant_splicing.done")
    output:
        touch(tmpdir + "/gdp_aberrant_splicing.done")

rule MAE:
    input:
        mae(tmpdir + "/mae.done")
    output:
        touch(tmpdir + "/gdp_mae.done")


rule getIndexNames:
    input:
        maeIndex= mae(tmpdir + "/mae.done"),
        abExpIndex=aberrantExp(tmpdir + "/aberrant_expression.done"),
#        abSpIndex=aberrantSplicing(tmpdir + "/aberrant_splicing.done"),
    output:
        indexFile=parser.getProcDataDir() + "/indexNames.txt"
    run: 
        indexList = [x for x in os.listdir(config["htmlOutputPath"]) if (re.search("_index.html$",x) and ("genetic_diagnosis" not in x))]
        with open(output.indexFile, 'w') as file_handler:
    	    for item in indexList:
                file_handler.write("{}\n".format(item))


rule gdp_overview:
    input:
        rules.Index.output, htmlOutputPath + "/gdp_readme.html"
    output:
        touch(tmpdir + "/gdp_overview.done")


### RULEGRAPH  
### rulegraph only works without print statements. Call <snakemake --configfile <configfile> produce_rulegraph> for producing output

## For rule rulegraph.. copy configfile in tmp file
import oyaml
with open(tmpdir + '/config.yaml', 'w') as yaml_file:
    oyaml.dump(config, yaml_file, default_flow_style=False)
    
rulegraph_filename = htmlOutputPath + "/" + os.path.basename(os.getcwd()) + "_rulegraph"
rule produce_rulegraph:
    input:
        expand(rulegraph_filename + ".{fmt}", fmt=["svg", "png"])

rule create_graph:
    output:
        rulegraph_filename + ".dot"
    shell:
        "snakemake --configfile" + tmpdir + "/config.yaml --rulegraph > {output}"

rule render_dot:
    input:
        "{prefix}.dot"
    output:
        "{prefix}.{fmt,(png|svg)}"
    shell:
        "dot -T{wildcards.fmt} < {input} > {output}"

