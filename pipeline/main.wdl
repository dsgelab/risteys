workflow RisteysPipelineMain {
	# FinnGen data
	File fg_minimum_data
	File fg_first_events
	File fg_endpoint_defs
	File fg_samples
	File icd10cm
	File icd10finn

	# Ontology
	File endpoint_mapping
	File EFO
	String ontology_output

	# Summary stats
	String dense_output
	String hdf_output
	String stats_hdf
	String stats_json

	# Associations
	String filtered_pairs

	call ontology {
		input:
			endpoint_mapping=endpoint_mapping,
			efo=EFO,
			soutput=ontology_output
	}

	call QC {
		input:
			fg_minimum_data=fg_minimum_data,
			fg_first_events=fg_first_events,
	}

	call densify_first_events {
		input:
			qc_first_events=QC.out,
			dense_output=dense_output,
	}

	call build_input {
		input:
			fg_minimum_data=fg_minimum_data,
			fg_samples=fg_samples,
			dense_output=densify_first_events.out,
			hdf_output=hdf_output
	}

	call aggregate_stats {
		input:
			input_hdf=build_input.out,
			hdf_output=stats_hdf,
			json_output=stats_json
	}

	call surv_endpoints {
		input:
			input_hdf=build_input.out,
			fg_endpoint_defs=fg_endpoint_defs,
			icd10cm=icd10cm,
			icd10finn=icd10finn,
			soutput=filtered_pairs
	}
}

task ontology {
	File endpoint_mapping
	File efo
	String soutput

	command {
		python3 /app/build_ontology.py ${endpoint_mapping} ${efo} ${soutput}
	}

	output {
		File out = "${soutput}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "2 GB"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task QC {
	File fg_minimum_data
	File fg_first_events

	command {
		python3 /app/qc.py ${fg_minimum_data} ${fg_first_events}
	}

	output {
		File out = fg_first_events
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "52 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task densify_first_events {
	File qc_first_events
	String dense_output

	command {
		densers < ${qc_first_events} > ${dense_output}
	}

	output {
		File out = "${dense_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys-densers"
		cpu: "1"
		memory: "2 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task build_input {
	File fg_minimum_data
	File fg_samples
	File dense_output
	String hdf_output

	command {
		python3 /app/build_input_hdf.py ${dense_output} ${fg_minimum_data} ${fg_samples} ${hdf_output}
	}

	output {
		File out = "${hdf_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "52 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task aggregate_stats {
	File input_hdf
	String hdf_output
	String json_output

	command {
		python3 /app/aggregate_by_endpoint.py ${input_hdf} ${hdf_output}
		python3 /app/stats_to_json.py ${hdf_output} ${json_output}
	}

	output {
		File out = "${json_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "26 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task surv_endpoints {
	File input_hdf
	File fg_endpoint_defs
	File icd10cm
	File icd10finn
	String soutput

	command {
		python3 /app/surv_endpoints.py ${input_hdf} ${fg_endpoint_defs} ${icd10cm} ${icd10finn} ${soutput}
	}

	output {
		File out = "${soutput}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "26 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}
