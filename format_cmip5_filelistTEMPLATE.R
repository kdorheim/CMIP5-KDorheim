## format_cmip5_filelistTEMPLATE.R
## Format the cmip5/filelist.txt into a list of netcdf files that we would like to 
## download. 
## This script is a template script, it must be launch from the pic terminal and for the most part 
## the formatting section will have to be customized for each use. 
##
## Written with R 3.4.3
# 0. Set Up ------------------------------------------------------------------------------------------------------
# Import the libraries
library(dplyr)
library(tidyr)
library(tibble)

# Set up the paths to the relevant locations on pic
CMIP5archive_DIR <- '/pic/projects/GCAM/CMIP5-KDorheim'
CMIP5dtn_DIR     <- '/pic/dtn/dorh012/cmip5'

# If there is some sort of corrupted file in th the filelist.txt you won't be able to import the txt files into R. 
# You will need to identify what lines are missing elements, to do this run the following on constance. 
#   awk '{if (!$5) {print $2 "/" $1, "Incomplete"}}' filelist.txt
# Then you will need to delete these lines with the following code. 
#   sed '/REGULAR_EXPRESSION/d'  filelist.txt > filelist-good.txt

# Check to see if the file list exsits. 
filelist_path <- file.path(CMIP5dtn_DIR, 'filelist-good.txt')
stopifnot(file.exists(filelist_path))

# This is a large file and so that it may take while to import the file. 
imported_file_list <- read.table(filelist_path, comment.char = '#', col.names = c('filename', 'path', 'checksum', 'creation_data', 'tracking_ID'))

# After importing the file list you need to 
cmip5_ETHZ_filelist <- data.frame(filename = as.character(imported_file_list[['filename']]), 
                                  path = as.character(imported_file_list[['path']]), stringsAsFactors = FALSE)

# 1. Format the CMIP information into a table --------------------------------------------------------------------

# There are lots of different types of files in the CMIP5 filelist. Make a pattern for each of the file types 
# to make is easier to parse out the information from the file names. 
abs550aer_pattern     <- 'abs550aer_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6}).nc'
native_pattern        <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_native.nc'
sftgif_pattern        <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+).nc'
CMIP5clim_pattern     <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6})-clim.nc'
CMIP5clim_pattern2    <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6})_clim.nc'
baresoilFrac_pattern  <- 'baresoilFrac_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6}).nc'

CMIP5data_mon_pattern <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6}).nc'
CMIP5data_day_pattern <- '([a-zA-Z0-9-]+)_day_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})-([0-9]{8}).nc'
CMIP5yr_pattern       <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{4})-([0-9]{4}).nc'
fx_pattern            <- '([a-zA-Z0-9-]+)_fx_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+).nc'

misc_patterns <- paste(abs550aer_pattern, baresoilFrac_pattern, CMIP5clim_pattern, CMIP5clim_pattern2, sep = '|')
data_patterns <- paste(CMIP5data_mon_pattern, CMIP5data_day_pattern, CMIP5yr_pattern, sep = '|')
meta_patterns <- paste(fx_pattern, sep = '|')

# Format the netcdf files that contain data. 
cmip5_ETHZ_filelist %>%  
  filter(!grepl(pattern = misc_patterns, x = filename)) %>% 
  filter(grepl(pattern = data_patterns, x = filename)) %>%
  separate(col = filename, into = c('variable', 'domain', 'model', 'experiment', 'ensemble', 'date'), sep = '_', remove = FALSE) %>% 
  mutate(date = gsub(pattern = '.nc', replacement = '', x = date), 
         type = 'data') -> 
  cmip5_data_files 

# Format the netcdf files that contain the meta data. 
cmip5_ETHZ_filelist %>%  
  filter(grepl(pattern = meta_patterns, x = filename)) %>%
  separate(col = filename, into = c('variable', 'domain', 'model', 'experiment', 'ensemble'), sep = '_', remove = FALSE) %>% 
  mutate(ensemble = gsub(pattern = '.nc', replacement = '', x = ensemble), 
         type = 'meta') -> 
  cmip5_meta_files 

# Create a complete data frame of the cmip5 data and meta data files. 
cmip5_ETHZ_files <- bind_rows(cmip5_data_files, cmip5_meta_files)

# 2. Identify which files have not already been downlaoded ------------------------------------------------------------
# Import the CMIP5 archive index
read.csv(file.path(CMIP5archive_DIR, 'cmip5_index.csv'), stringsAsFactors = FALSE) %>% 
  rename(exists = file) %>% 
  select(-type) ->
  cmip5_archive

cmip5_ETHZ_files %>%  
  full_join(cmip5_archive) %>% 
  filter(is.na(exists)) -> 
  to_download 


# 3. Select the files to download ------------------------------------------------------------
to_download %>%  
  # Select the files to download 
  # filter(var %in% vars and so on)  %>% 
  select(path, nc) %>%
  mutate(file = paste0(path, '/', nc)) %>%
  pull(file) ->
  to_download

write.table(to_download, file = file.path(DTN2_DIR, 'to_download.txt'), row.names = FALSE, quote = FALSE, col.names = FALSE)
