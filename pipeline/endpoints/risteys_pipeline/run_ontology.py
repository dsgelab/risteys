"""Generate the ontology file containing the EFO, MESH, and DOID mappings and endpoint descriptions"""

import pandas as pd
import numpy as np
import json


def read_efo_doid_data(path):
    """
    Read EFO and DOID data. Renames the columns.
    
    Args: 
        path (str): path to the annotated_ontology.csv file 

    Returns: 
        efo (DataFrame): dataframe with columns `endpoint`, `efo`, and `doid`
    """
    cols = ["endpoint_name", "FINAL ANNOTATION_EFO", "FINAL ANNOTATION_DOID"]
    efo = pd.read_csv(path, sep=";", header=0, usecols=cols)
    efo.columns = ["endpoint", "efo", "doid"]
    return efo


def read_mesh_data(path):
    """
    Read MESH mapping data. Renames the columns.
    Endpoints with multiple rows are combined and the DOID and MESH codes in their respective columns are delimited by space.

    Args:  
        path (str): path to the R4_ontology_mapping.txt file 

    Returns: 
        mesh (DataFrame): dataframe with columns `endpoint` and `mesh` 
    """
    cols = ["NAME", "best_doid", "MESH"]
    mesh = pd.read_csv(path, sep="\t", encoding="latin9", usecols=cols, dtype=str)
    mesh.columns = ["endpoint", "doid", "mesh"]
    mesh = (
        mesh.fillna("")
        .groupby("endpoint", as_index=True)
        .agg({"mesh": lambda x: " ".join(x), "doid": lambda x: " ".join(x)})
    )
    mesh["mesh"] = mesh["mesh"].str.strip()
    mesh["doid"] = mesh["doid"].str.replace(",", " ").str.strip()
    mesh = mesh.replace({"": pd.NA})
    return mesh


def read_descriptions_data(path):
    """
    Read endpoint descriptions data.

    Args: 
        path (str): path to the out_ontology__2020-08-10.json

    Returns:    
        descriptions (DataFrame): dataframe with columns `endpoint` and `description`
    """
    descriptions = pd.read_json(path, orient="index")
    descriptions = (
        descriptions["description"].reset_index().rename(columns={"index": "endpoint"})
    )
    return descriptions


def select_first_code(df, col, delim=" "):
    """
    Select the first code before the delimiter.
    The value is NA if there are no codes.
    
    Args:  
        df (DataFrame): pandas dataframe 
        col (str): name of the column in the dataframe 
        delim (str): delimiter separating the codes

    Returns: 
        res (Series): column df[col] with the first code selected 
    """
    res = df[col].str.split(delim).str[0]
    return res


def format_codes(df):
    """
    Format codes by removing the prefix.
    - EFO: remove everything before "_", e.g. EFO_1234 -> 1234
    - DOID: remove everything before ":", "-", or "_", e.g. DOID:1234 -> 1234 and DOID_1234 -> 1234
    - MESH: no formatting
    
    Args: 
        df (DataFrame): pandas dataframe with columns `first_efo`, `first_doid`, and `first_mesh`

    Output: 
        df (DataFrame): pandas dataframe with codes formatted
    """
    df["first_efo"] = df["first_efo"].str.split("_").str[1]
    df["first_doid"] = df["first_doid"].str.split("[:_-]").str[1]
    return df


def preprocess_data(efo_doid, mesh, descriptions):
    """
    Preprocess data
    - combine the datasets 
    - select the first EFO, DOID, and MESH code 
    - format EFO, DOID, and MESH codes

    Args: 
        efo_doid (DataFrame): EFO and DOID mappings dataset
        mesh (DataFrame): mesh mappings dataset
        descriptions (DataFrame): descriptions dataset

    Returns: 
        df (DataFrame): dataset containing the first EFO, DOID, and MESH code and the endpoint description (when available) 
    """

    # Combine EFO, DOID, and MESH
    df = efo_doid.merge(mesh, how="outer", on="endpoint", suffixes=("_new", "_old"))

    # Use DOID from the new file (`efo_doid`) when available, otherwise use the old file (`mesh`)
    df["doid"] = np.where(~df["doid_new"].isnull(), df["doid_new"], df["doid_old"])

    # Select the first EFO, DOID, and MESH code
    df["first_efo"] = select_first_code(df, "efo")
    df["first_doid"] = select_first_code(df, "doid")
    df["first_mesh"] = select_first_code(df, "mesh")

    # Format codes
    df = format_codes(df)

    # Add endpoint descriptions
    df = df.merge(descriptions, how="outer", on="endpoint")

    return df


def write_data_to_json(df, output_path, write=True):
    """
    Write data to a JSON file. 
    
    The following columns are used: 
    - `endpoint`: used as an index
    - `first_efo`, `first_doid`, `first_mesh`: renamed to `EFO`, `DOID`, and `MESH`
    - `description`

    Columns with missing values are omitted from the output.
    EFO, DOID, and MESH codes are formatted as lists.

    Args:
        df (DataFrame): dataframe with columns `endpoint`, `first_efo`, `first_doid`, `first_mesh`, and `description`
        output_dir (str): path for the output JSON file
    """
    cols = ["endpoint", "description", "first_efo", "first_doid", "first_mesh"]
    df = df[cols].rename(
        columns={"first_efo": "EFO", "first_doid": "DOID", "first_mesh": "MESH"}
    )
    df_dict = df.set_index("endpoint").to_dict(orient="index")
    df_dict = {
        endpoint: {
            key: [value] if key != "description" else value
            for key, value in codes.items()
            if not pd.isna(value)
        }
        for endpoint, codes in df_dict.items()
    }

    if write:
        with open(output_path, "x") as f:
            json.dump(df_dict, f)

    return df_dict


if __name__ == "__main__":

    # Read data
    efo_doid = read_efo_doid_data("../data/ontology/annotated_ontology.csv")
    mesh = read_mesh_data("../data/ontology/R4_ontology_mapping.txt")
    desc = read_descriptions_data("../data/ontology/out_ontology__2020-08-10.json")

    # Preprocess data
    df = preprocess_data(efo_doid, mesh, desc)

    # Write data to JSON
    write_data_to_json(df, "../data/ontology/ontology_2022-08-22.json")

