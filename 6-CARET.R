
# title: 6 - MACHINE LEARNING WITH CARET
# author: "Joseph Rickert"
# date: "10/21/15"


# caret (short for Classification and REgression Training) is the 
# most feature rich package for doing machine learning in R. 
# It provides functions to streamline the entire process and includes tools for:   
#    * data splitting    
#    * pre-processing    
#    * feature selection    
#    * model tuning using resampling    
#    * variable importance estimation    
# 
# This script explores caret's capabilities using a cell segmentation data 
# set that is included in the package. The data is described in the paper: 
# Hill et al "Impact of image segmentation on high-content screening 
# data quality for SK-BR-3 cells" BMC fioinformatics (2007) vol 8 (1) pp. 340
# 
# The analysis presented here is based on examples presented by Max Kuhn, caret's author, at Use-R 2012.

### Background
# "Well-segmented"" cells are cells for which location and size may be 
# accurrately detremined through optical measurements. Cells that are 
# not Well-segmented (WS) are said to be "Poorly-segmented"" (PS). 
# Given a set of optical measurements can we predict which cells will be PS? 
# This is a classic classification problem

### Packages Required

library(caret)
library(corrplot)			# plot correlations
library(doParallel)		# parallel processing
library(dplyr)         # Used by caret
library(gbm)				  # Boosting algorithms
library(kernlab)      # support vector machine 
library(partykit)			# Plotting trees
library(pROC)				  # plot the ROC curve
library(rpart)  			# CART algorithm for decision trees
 
### Get the Data
# Load the data and construct indices to divied it into training and test data sets.

data(segmentationData)  	# Load the segmentation data set
dim(segmentationData)
head(segmentationData,2)
#
trainIndex <- createDataPartition(segmentationData$Case,p=.5,list=FALSE)
trainData <- segmentationData[trainIndex,-c(1,2)]
testData  <- segmentationData[-trainIndex,-c(1,2)]
#
trainX <-trainData[,-1]        # Pull out the dependent variable
testX <- testData[,-1]
sapply(trainX,summary) # Look at a summary of the training data
   

## GENERALIZED BOOSTED REGRGRESSION MODEL   
# We build a gbm model. Note that the gbm function does not 
# allow factor "class" variables

gbmTrain <- trainData
gbmTrain$Class <- ifelse(gbmTrain$Class=="PS",1,0)
gbm.mod <- gbm(formula = Class~.,  			# use all variables
               distribution = "bernoulli",		  # for a classification problem
               data = gbmTrain,
               n.trees = 2000,					        # 2000 boosting iterations
               interaction.depth = 7,			    # 7 splits for each tree
               shrinkage = 0.01,				        # the learning rate parameter
               verbose = FALSE)				        # Do not print the details

summary(gbm.mod)			# Plot the relative inference of the variables in the model
 
# This is an interesting model, but how do you select the best 
# values for the for the three tuning parameters?   
#    * n.trees   
#    * interaction.depth   
#    * shrinkage   

### GBM Model Training Over Paramter Space
# caret provides the "train" function that implements the following algorithm: 
  
# Algorithm for training the model:    
# Define sets of model parameters to evaluate    
# for each parameter set do    
# ....for each resampling iteration do    
# ......hold out specific samples     
# ......pre-process the data    
# ......fit the model to the remainder    
# ....predict the holdout samples    
# ....end      
# ....calculate the average performance across hold-out predictions    
# end    
# Determine the optimal parameter set    
# Fit the final model to the training data using the optimal parameter set    
# 
# Note the default method of picking the best model is accuracy and Cohen's Kappa   

# Set up training control
ctrl <- trainControl(method="repeatedcv",   # 10fold cross validation
          repeats=5,							          # do 5 repititions of cv
          summaryFunction=twoClassSummary,	# Use AUC to pick the best model
          classProbs=TRUE)

# Use the expand.grid to specify the search space	
# Note that the default search grid selects 3 values of each tuning parameter

grid <- expand.grid(interaction.depth = seq(1,4,by=2), #tree depths from 1 to 4
                    n.trees=seq(10,100,by=10),	# let iterations go from 10 to 100
                    shrinkage=c(0.01,0.1),			# Try 2 values fornlearning rate 
                    n.minobsinnode = 20)
#											
set.seed(1951)                     # set the seed to 1

# Set up to to do parallel processing   

registerDoParallel(4)		# Registrer a parallel backend for train
getDoParWorkers()

system.time(gbm.tune <- train(x=trainX,y=trainData$Class,
                              method = "gbm",
                              metric = "ROC",
                              trControl = ctrl,
                              tuneGrid=grid,
                              verbose=FALSE))


# Look at the tuning results
# Note that ROC was the performance criterion used to select the optimal model.   

gbm.tune$bestTune
plot(gbm.tune)  		# Plot the performance of the training models
res <- gbm.tune$results
names(res) <- c("depth","trees", "shrinkage","ROC", "Sens","Spec", "sdROC", 
                "sdSens", "seSpec")
res


### GBM Model Predictions and Performance
# Make predictions using the test data set

gbm.pred <- predict(gbm.tune,testX)
head(gbm.pred)

#Look at the confusion matrix  
confusionMatrix(gbm.pred,testData$Class)   

#Draw the ROC curve 
gbm.probs <- predict(gbm.tune,testX,type="prob")
head(gbm.probs)

gbm.ROC <- roc(predictor=gbm.probs$PS,
response=testData$Class,
levels=rev(levels(testData$Class)))
gbm.ROC

plot(gbm.ROC)
  
# Plot the propability of poor segmentation

histogram(~gbm.probs$PS|testData$Class,xlab="Probability of Poor Segmentation")


## SUPPORT VECTOR MACHINE MODEL 
# We follow steps similar to those above to build a SVM model    
   
# Set up for parallel procerssing
set.seed(1951)
registerDoParallel(4,cores=4)
getDoParWorkers()

# Train and Tune the SVM

system.time(
svm.tune <- train(x=trainX,
y= trainData$Class,
             method = "svmRadial",
             tuneLength = 9,					# 9 values of the cost function
             preProc = c("center","scale"),
             metric="ROC",
             trControl=ctrl)	# same as for gbm above
)	

svm.tune
  
#Plot the SVM results   
plot(svm.tune,metric="ROC",scales=list(x=list(log=2)))

# Make predictions on the test data with the SVM Model   
  
svm.pred <- predict(svm.tune,testX)
head(svm.pred)

confusionMatrix(svm.pred,testData$Class)

svm.probs <- predict(svm.tune,testX,type="prob")
head(svm.probs)

svm.ROC <- roc(predictor=svm.probs$PS,
response=testData$Class,
levels=rev(levels(testData$Class)))
svm.ROC

plot(svm.ROC)
  

## RANDOM FOREST MODEL

set.seed(1951)
rf.tune <-train(x=trainX,
                y= trainData$Class,
                method="rf",
                trControl= ctrl,
                prox=TRUE,allowParallel=TRUE)
rf.tune

# Plot the Random Forest results
plot(rf.tune,metric="ROC",scales=list(x=list(log=2)))

# Random Forest Predictions
rf.pred <- predict(rf.tune,testX)
head(rf.pred)

confusionMatrix(rf.pred,testData$Class)

rf.probs <- predict(rf.tune,testX,type="prob")
head(rf.probs)

rf.ROC <- roc(predictor=rf.probs$PS,
response=testData$Class,
levels=rev(levels(testData$Class)))
rf.ROC

plot(rf.ROC,main = "Random Forest ROC")

## Comparing Multiple Models
# Having set the seed to 1 before running gbm.tune, 
# svm.tune and rf.tune we have generated paired samples 
# (See Hothorn at al, "The design and analysis of benchmark experiments
# -Journal of Computational and Graphical Statistics (2005) vol 14 (3) 
# pp 675-699) and are in a position to compare models using a resampling technique.

rValues <- resamples(list(svm=svm.tune,gbm=gbm.tune,rf=rf.tune))
rValues$values
summary(rValues)

bwplot(rValues,metric="ROC")		    # boxplot
dotplot(rValues,metric="ROC")		    # dotplot
splom(rValues,metric="ROC")
