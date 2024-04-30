workflow RisteysSurv {
     String scriptDir
     File FGEndpointDefinitions
     File FGPriorityEndpoints
     File FGPhenoCorrelations
     File FGMinimumInfo
     File RisteysDenseFirstEvents

     call selectPairs {
          input:
                defs = FGEndpointDefinitions,
                prios = FGPriorityEndpoints,
                corrs = FGPhenoCorrelations,
                scriptDir = scriptDir,
                soutput = "pairs.csv"
     }

     call splitPairs {
          input:
                pairs = selectPairs.out,
                soutput = "pairs/"
     }

     scatter (batchPairs in splitPairs.out) {
     	     call survAnalysis {
	     	  input:
                      inPairs = batchPairs,
                      inDefs = FGEndpointDefinitions,
                      inDense = RisteysDenseFirstEvents,
                      inInfo = FGMinimumInfo,
                      scriptDir = scriptDir,
		      outPath = basename(batchPairs, ".csv") + "_out.csv",
		      outTimings = basename(batchPairs, ".csv") + "_timings.csv"
		}
     }

     call concatCompress {
     	  input: intermediates = survAnalysis.out, outPath = "out.csv.zst"
     }
}

task selectPairs {
     File defs
     File prios
     File corrs
     String scriptDir
     String soutput
     
     command {
             python3 ${scriptDir}/surv_select_endpoint_pairs.py -e ${defs} -p ${prios} -c <(zstd -dcq ${corrs}) -o ${soutput}
     }

     output {
            File out = "${soutput}"
     }

     runtime {
     	     docker: "eu.gcr.io/finngen-refinery-dsgelab/risteys-pipeline-survival-analysis"
     	     preemptible: 1
	     cpu: 1
	     memory: "8 GB"
     	     disks: "local-disk 10 HDD"
     	     zones: "europe-west1-b europe-west1-c europe-west1-d"
     	     noAddress: true
     }
}

task splitPairs {
     File pairs
     String soutput

     command {
             xsv split -s 500 ${soutput} ${pairs}
     }

     output {
            Array[File] out = glob("${soutput}/*.csv")
     }
     runtime {
     	     docker: "eu.gcr.io/finngen-refinery-dsgelab/risteys-pipeline-survival-analysis"
     	     preemptible: 1
	     cpu: 1
	     memory: "8 GB"
     	     disks: "local-disk 10 HDD"
     	     zones: "europe-west1-b europe-west1-c europe-west1-d"
     	     noAddress: true
     }
}

task survAnalysis {
     File inPairs
     File inDefs
     File inDense
     File inInfo
     String outPath
     String outTimings
     String scriptDir

     command {
     	     env INPUT_PAIRS=${inPairs} \
   	     INPUT_DEFINITIONS=${inDefs} \
    	     INPUT_DENSE_FEVENTS=${inDense} \
    	     INPUT_INFO=${inInfo} \
    	     OUTPUT=${outPath} \
   	     TIMINGS=${outTimings} \
	     python3 ${scriptDir}/surv_analysis.py
     }

     output {
     	    File out = "${outPath}"
	    File timings = "${outTimings}"
     }

     runtime {
     	     docker: "eu.gcr.io/finngen-refinery-dsgelab/risteys-pipeline-survival-analysis"
     	     preemptible: 1
	     cpu: 1
	     memory: "8 GB"
     	     disks: "local-disk 10 HDD"
     	     zones: "europe-west1-b europe-west1-c europe-west1-d"
     	     noAddress: true
     }
}

task concatCompress {
     Array[String] intermediates
     String outPath
     
     command {
     	     xsv cat rows ${sep=" " intermediates} | zstd -q -o ${outPath}
     }

     output {
     	    File out = "${outPath}"
     }
     runtime {
     	     docker: "eu.gcr.io/finngen-refinery-dsgelab/risteys-pipeline-survival-analysis"
     	     preemptible: 1
	     cpu: 1
	     memory: "8 GB"
     	     disks: "local-disk 10 HDD"
     	     zones: "europe-west1-b europe-west1-c europe-west1-d"
     	     noAddress: true
     }
}