defmodule Risteys.Repo.Migrations.RenamingPhenocodeToFGEndpoint do
  use Ecto.Migration

  def change do
    # --- Main tables: "phenocodes" and its ICD join tables
    # 1. Drop indexes, as it is not possible to rename
    drop index(:phenocodes_icd10s, [:registry, :phenocode_id, :icd10_id], name: :phenocode_icd10_registry, unique: true)
    drop index(:phenocodes_icd9s, [:registry, :phenocode_id, :icd9_id], name: :phenocode_icd9_registry, unique: true)

    # 2. Rename table columns
    rename table("phenocodes_icd10s"), :phenocode_id, to: :fg_endpoint_id
    rename table("phenocodes_icd9s"), :phenocode_id, to: :fg_endpoint_id

    # 3. Rename tables
    rename table("phenocodes"), to: table(:fg_endpoint_definitions)
    rename table("phenocodes_icd10s"), to: table(:fg_endpoint_definitions_icd10s)
    rename table("phenocodes_icd9s"), to: table(:fg_endpoint_definitions_icd9s)

    # 4. Recreate indexes with renaming
    create unique_index(:fg_endpoint_definitions, [:name])
    create unique_index(:fg_endpoint_definitions_icd10s, [:registry, :fg_endpoint_id, :icd10_id], name: :fg_endpoint_definition_icd10_registry)
    create unique_index(:fg_endpoint_definitions_icd9s, [:registry, :fg_endpoint_id, :icd9_id], name: :fg_endpoint_definition_icd9_registry)


    # --- Dependent tables: referencing the "phenocodes"
    # 5. Drop indexes
    drop index(:correlations, [:phenocode_a_id, :phenocode_b_id], name: :phenocode_a_b, unique: true)
    drop index(:drug_stats, [:phenocode_id, :atc_id], name: :phenocode_atc, unique: true)
    drop index(:endp_explainer_step, [:phenocode_id, :step], name: :phenocode_step, unique: true)
    drop index(:mortality_stats, [:phenocode_id, :lagged_hr_cut_year], name: :phenocode_hrlag, unique: true)
    drop index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id, unique: true)

    # 6. Rename table columns
    rename table(:correlations), :phenocode_a_id, to: :fg_endpoint_a_id
    rename table(:correlations), :phenocode_b_id, to: :fg_endpoint_b_id
    rename table(:drug_stats), :phenocode_id, to: :fg_endpoint_id
    rename table(:endp_explainer_step), :phenocode_id, to: :fg_endpoint_id
    rename table(:stats_cumulative_incidence), :phenocode_id, to: :fg_endpoint_id
    rename table(:mortality_stats), :phenocode_id, to: :fg_endpoint_id
    rename table(:stats_sex), :phenocode_id, to: :fg_endpoint_id

    # 7. Recreate indexes with renaming
    create unique_index(:correlations, [:fg_endpoint_a_id, :fg_endpoint_b_id], name: :fg_endpoint_a_b)
    create unique_index(:drug_stats, [:fg_endpoint_id, :atc_id], name: :fg_endpoint_atc)
    create unique_index(:endp_explainer_step, [:fg_endpoint_id, :step], name: :fg_endpoint_step)
    create unique_index(:mortality_stats, [:fg_endpoint_id, :lagged_hr_cut_year], name: :fg_endpoint_hrlag)
    create unique_index(:stats_sex, [:sex, :fg_endpoint_id], name: :sex_fg_endpoint_id)
  end
end
