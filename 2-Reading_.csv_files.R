
# Reading .csv files
# MLADS JJune 2016
# author: "Joseph Rickert"
# date: "May 9, 2016"
# 
# In this module we will read a .csv file from the web by using its 
# url and put it into and R data frame. Then we will write the data to disk 
# as a .csv file and read it back into the R environment.


## Fetch some data from Yahoo Finance  
# Go to http://finance.yahoo.com/q/hp?s=IBM+Historical+Prices 
# Go to the bottom of the page where it says "Download Spreadsheet"
# Copy the link to the table. Then read the data directly from the URL into an R 
# data frame.


url <- "http://real-chart.finance.yahoo.com/table.csv?s=IBM&d=1&e=1&f=2016&g=d&a=0&b=2&c=1962&ignore=.csv"
IBM.stock <- read.table(url,header=TRUE,sep=",")
head(IBM.stock)

## Write the data to disk
# Having taken the trouble to fetch the data from the web we can write 
# it to a local disk,but where shall we write the data. The following command will
# write it to the current working directory.


write.csv(IBM.stock,file="IBM.stock.csv",row.names=FALSE)
getwd()           # Get the path to the local directory

# It is good practice, however, to put data in its own permanent directory. 
# I have a directory called "DATA" on my C drive (C:\DATA) under which 
# I store data in subdirectories. The following code shows how to create a 
# directory from within R and then write the data there.  

# Create a directory to store the data
dirName <- "IBM"
dirPath <- "C:/DATA"
dir <- file.path(dirPath,dirName)
dir.create(path=dir, showWarnings = TRUE, recursive = FALSE)

# Write the data to a .csv file
fileName <- "IBM.stock.csv"
file <- file.path(dir,fileName)
write.csv(IBM.stock,file=file,row.names=FALSE)

# See if the file is in the directory
list.files(dir)

## Read the .csv file from disk

# first remove the data frame from the R environment
rm(IBM.stock)
IBM.stock <- read.csv(file)
head(IBM.stock,2)






