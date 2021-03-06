library(randomForest)
library(ranger)
library(strip)

expertRFTrain <- function(now, rdb = NULL, fdb = NULL, set = 1,
                          dxn = P_DXN, idn = P_IDN, rtn = P_RTN, v = F) {
  # Trains an expert using random forest on past data (now or earlier)
  #
  # Args:
  #   now: the latest time index that the model can access.
  #   rdb: data frame containing return data (default = use global default)
  #   fdb: data frame containing financial ratio data (default = use global default)
  #   set: predictor set = one of (1, 2) (default = 1)
  #   dxn: column name for dex (default = P_DXN)
  #   idn: column name for ids (default = P_IDN)
  #   rtn: column name for returns (default = P_RTN)
  #   v: verbose mode if true
  #
  # Returns:
  #   One trained random forest model object
  
  # Validate set
  if (!(set %in% c(1,2))) {
    print("WARNING in expertRFTrain: invalid set ID; SET #1 will be used.")
    set <- 1
  }
  
  # Keep track of time
  st <- Sys.time()
  
  # Log file
  note("expertRFTrain: training expert(s) at time", now, lvl = 2)
  
  # Get data panel
  panel <- gatherData(T, now, set = set, rdb = rdb, fdb = fdb, 
                      dxn = dxn, idn = idn, rtn = rtn)
  
  # Training set
  tr <- panel[, -1] # Remove the first column (IDs)
  note("expertRFTrain: the training set has", dim(tr)[1], "rows and", dim(tr)[2], "cols.", lvl = 2)
  
  
  # Train random forest model ----
  
  # First pass
  tm()
  rf.mdl <- ranger(y ~ ., data = tr, num.trees = P_RFNTR, importance = "impurity")
  note("expertRFTrain: randomForest training took", tm(F), "secs.", lvl = 2)
  note("expertRFTrain: randomForest OOB correlation", cor(rf.mdl$predictions, panel$y), lvl = 2)
  
  # Track variable importance
  imps <- rf.mdl$variable.importance
  imps.df <- data.frame(imps)
  imps.df[, "var"] <- row.names(imps.df)
  row.names(imps.df) <- NULL
  imps.df[, dxn] <- now
  track("imp", imps.df)
  imp.names <- c(names(imps)[imps > quantile(imps, 0.2)], "y")
  
  # Second pass - after eliminating the least important 20% of predictors
  tr2 <- tr[, imp.names]
  rf.mdl <- ranger(y ~ ., data = tr2, num.trees = P_RFNTR2, importance="impurity")
  
  
  
  # Output
  out <- list()
  out[[1]] <- rf.mdl
  
  note("expertRFTrain: returning 1 model: randomForest.", lvl = 2)
  
  # Record the time
  note("expertRFTrain: runtime =", as.numeric(Sys.time() - st)[1], lvl = 2)
  
  return(out)
}

# # Debug code
# models <- expertRFTrain(901, v=T)

# resetTracker("imp")

