##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Project:       Update Metadata Tables in Oracle
## Description:   Pull the most recent version of the future oracle spreadsheet
##                google sheet, save locally, then upload to GAP_PRODUCTS. 
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls())

##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   Import Libraries and constants, connect to Oracle
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
library(googledrive)
library(gapindex)
library(readxl)
library(janitor)
library(dplyr)
source(file = "code/functions.R")

chl <- gapindex::get_connected(check_access = F)

##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   Download the most recent version of the future_oracle.xlsx 
##   google sheet and save locally in the temp folder. 
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
googledrive::drive_download(
  file = googledrive::as_id("1wgAJPPWif1CC01iT2S6ZtoYlhOM0RSGFXS9LUggdLLA"), 
  path = "temp/future_oracle.xlsx", 
  overwrite = TRUE)

##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   Clean up metadata_table: the table that houses the shared sentence 
##   fragments that will describe each table. 
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
metadata_table <- readxl::read_xlsx(path = "temp/future_oracle.xlsx", 
                                    sheet = "METADATA_TABLE") 
# metadata_table$metadata_sentence <- gsub(x = metadata_table$metadata_sentence,
#                                          pattern = "INSERT_CODE_BOOK", 
#                                          replacement = link_code_books)
# AREA <- subset(x = readxl::read_xlsx(path = "temp/future_oracle.xlsx",
#                                      sheet = "AREA"),
#                select = -AREAJOIN)
# STRATUM_GROUPS <- readxl::read_xlsx(path = "temp/future_oracle.xlsx", 
#                                     sheet = "STRATUM_GROUPS") 
# SURVEY_DESIGN <- readxl::read_xlsx(path = "temp/future_oracle.xlsx", 
#                                     sheet = "SURVEY_DESIGN") 
shared_metadata_comment <-
  with(metadata_table,
       paste(
         metadata_sentence[metadata_sentence_name == "survey_institution"],
         gsub(pattern = "INSERT_REPO", replacement = link_repo,
              x = metadata_sentence[metadata_sentence_name == "github"]),
         gsub(pattern = "INSERT_DATE", replacement = pretty_date,
              x = metadata_sentence[metadata_sentence_name == "last_updated"]),
         metadata_sentence[metadata_sentence_name == "legal_restrict_none"],
         metadata_sentence[metadata_sentence_name == "codebook"])
  )

metadata_table_comment <- paste(
  "This table is used to string together the various table comments for the tables in GAP_PRODUCTS. These tables are created", shared_metadata_comment
)

##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   Clean up metadata_column: df that houses metadata column info
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
metadata_column <- readxl::read_xlsx( ## import spreadsheet
  path = "temp/future_oracle.xlsx",
  sheet = "METADATA_COLUMN",
  skip = 1) %>%
  janitor::clean_names() %>% ## clean field names
  ## select fields that start with "metadata_"
  dplyr::select(dplyr::starts_with("metadata_")) %>%
  ## filter out true NAs, "", "NA", and nulls in field "metadata_colname"
  dplyr::filter(!is.na(metadata_colname)) %>%
  dplyr::filter(!is.null(metadata_colname)) %>%
  dplyr::filter(!(metadata_colname %in% c("", "NA"))) %>%
  dplyr::mutate(
    ## input the links to the codebook
    metadata_colname_desc = gsub(pattern = "INSERT_CODE_BOOK",
                                 replacement = link_code_books,
                                 x = metadata_colname_desc),
    ## remove extra spaces?
    metadata_colname_desc = gsub(pattern = "  ",
                                 replacement = " ",
                                 x = metadata_colname_desc,
                                 fixed = TRUE),
    ## remove extra periods?
    metadata_colname_desc = gsub(pattern = "..",
                                 replacement = ".",
                                 x = metadata_colname_desc,
                                 fixed = TRUE))

##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##  Upload the two tables to Oracle
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
for (isql_table in c("metadata_table"#, 
                     #"metadata_column",
                    # "AREA", "STRATUM_GROUPS", 
                     #"SURVEY_DESIGN")
                     )) { ## loop over tables -- start
  
  ## Temporary dataframe that houses comment on each field The 
  ## field names in get(x = isql_table) should match those in 
  ## `metadata_column$metadata_colname`. If they don't, modify the future_oracle
  ## spreadsheet and reimport. 
  temp_metadata_column <- subset(x = metadata_column, 
                                 subset = metadata_colname %in% 
                                   toupper(names(x = get(x = isql_table))))
  
  ## In gapindex::upload_oracle, the `table_metadata` argument requires 
  ## specific field names
  names(x = temp_metadata_column) <- gsub(x = names(x = temp_metadata_column),
                                          pattern = "metadata_",
                                          replacement = "")
  
  ## Temporary comment on the table itself
  temp_metadata_comment <- get(x = paste0(isql_table, "_comment"))
  
  ## Upload table: gapindex function will drop the table if it already exists,
  ## saves the table, then adds the comment on the table and each column.
  gapindex::upload_oracle(x = get(x = isql_table), 
                          table_name = toupper(x = isql_table), 
                          metadata_column = temp_metadata_column, 
                          table_metadata = temp_metadata_comment, 
                          channel = chl, 
                          schema = "GAP_PRODUCTS", 
                          share_with_all_users = TRUE)
  
} ## loop over tables -- end
