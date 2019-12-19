## cmip5_index.R
## Search the CMIP5 archive and create an index of the files stored on pic.

# 0. Set Up ---------------------------------------------------------------
# Load the required libs
library(dplyr)
library(tidyr)
library(tibble)

# Define the directories
CMIP_DIR <- '/pic/projects/GCAM/CMIP5-KDorheim/archive' # this should be the location of the CMIP6 data archive 
WRITE_TO <- file.path(CMIP_DIR, '../')

# 1. Find Files ---------------------------------------------------------------
# Find the CMIP5 files. 
file  <- list.files(path = CMIP_DIR, pattern = '.nc', full.names = TRUE, recursive = TRUE)

# Define the serach pattern for the different file types. 
month_data_pattern <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{6})-([0-9]{6}).nc'
day_data_pattern   <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{8})-([0-9]{8}).nc'
hr_data_pattern    <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{12})-([0-9]{12}).nc'
subHr_data_pattern <- '([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([0-9]{14})-([0-9]{14}).nc'
data_pattern       <- paste(month_data_pattern, day_data_pattern, hr_data_pattern, subHr_data_pattern, sep = '|')
fx_pattern         <- '([a-zA-Z0-9-]+)_fx_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+)_([a-zA-Z0-9-]+).nc'

# Categorize the files by the file type.
tibble(file = file) %>%  
  mutate(type = if_else(grepl(pattern = data_pattern, x = file), 'data', 'NA')) %>%  
  mutate(type = if_else(grepl(pattern = fx_pattern, x = file), 'fx', type)) -> 
  categorized_data 

# Parse out the cmip information from the data files. 
categorized_data %>% 
  dplyr::filter(type == 'data') %>% 
  mutate(name = gsub(pattern = '.nc', replacement = '', x = basename(file))) %>% 
  tidyr::separate(col = name, into = c('variable', 'domain', 'model', 'experiment', 'ensemble', 'time'), sep = '_') -> 
  data_df

# Parse out the cmip information from the meta data files. 
categorized_data %>% 
  dplyr::filter(type == 'fx') %>% 
  mutate(name = gsub(pattern = '.nc', replacement = '', x = basename(file))) %>% 
  tidyr::separate(col = name, into = c('variable', 'domain', 'model', 'experiment', 'ensemble'), sep = '_') -> 
  fx_df

# 2. Save ---------------------------------------------------------------
# Save data frames
data_df %>% 
  bind_rows(fx_df) %>% 
  write.csv(file = file.path(WRITE_TO, 'cmip5_index.csv'), row.names = FALSE)
