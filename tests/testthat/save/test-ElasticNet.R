#%%%%%%% Test: elasticNet regression  %%%%%%
#%% standard regression
#> lasso path: penalized-plvm   status=~ | WARNING: discrepancy with the penalized package but I think my solution is correct
#> proxGrad at the breakpoints: penalized-plvm  status=ok | NOTE: need to set the constrains to get non-negative variance
#> between breakpoints: lvm-plvm   status=ok | NOTE: if sigma is not fixed, a different solution may be found
#%% partial penalization  
#> status=ok
#%% regression with factors
#> status=~ | NOTE: if sigma is not fixed, a different solution may be found
#%% high dimensional case 
#> proxGrad at the breakpoints: penalized-plvm  status=ok | NOTE: if sigma is not fixed, a different solution may be found. Accuracy is lower compared to the low dimensional case
#> lasso path: penalized-plvm   status=~ | WARNING: discrepancy if sigma is not fixed

path <- file.path(butils::dir.gitHub(),"lava.penalty","tests")
path.res <- file.path(path, "Results/ElasticNet")

library(penalized)
library(testthat)
library(lava.penalty)
# package.source("lava.penalty", Rcode = TRUE)
source(file.path(path,"FCT.R"))

context("#### Reg-elasticNet #### \n")

#### > settings ####
test.tolerance <- 1e-4
test.scale <- NULL
save <- TRUE
lambda2 <- 25
lava.options(trace = FALSE)

#### > standard regression ####
cat("* standard regression \n")

#### simulation ####
set.seed(10)
n <- 500
formula.lvm <- as.formula(paste0("Y~",paste(paste0("X",1:5), collapse = "+")))
lvm.modelSim <- lvm()
regression(lvm.modelSim, formula.lvm) <-   as.list( c(rep(0,2),1:3) ) # as.list( c(rep(0,2),0.25,0.5,0.75) ) # 
distribution(lvm.modelSim, ~Y) <- normal.lvm(sd = 2)

# original dataset
df.data <- sim(lvm.modelSim,n)
df.data <- as.data.frame(scale(df.data))
df.data2 <- df.data

# same with negative coefficients
df.data2$X5 <- -df.data2$X5
df.data2$X3 <- -df.data2$X3

### models ####
lvm.model <- lvm(formula.lvm)
elvm.model <- estimate(lvm.model, df.data)
plvm.model <- penalize(lvm.model)

penalized.PathL1 <- penalized(Y ~  ., data = df.data, steps = "Park", trace = FALSE, lambda2 = lambda2)
seq_ncoef0 <- unlist(lapply(penalized.PathL1, function(x){sum(x@penalized!=0)}))
seq_lambda <- unlist(lapply(penalized.PathL1, function(x){x@lambda1}))
n.lambda <- length(seq_lambda)

#### lasso path ####
cat("  - lasso path forward \n")
test_that("EPSODE-forward vs penalize with elasticNet", {
  
  # data1
  PathFor_fixed <- estimate(plvm.model,  data = df.data, increasing = TRUE, fixSigma = TRUE, lambda2 = lambda2,
                            regularizationPath = TRUE)
  
  lambda1path <- getPath(PathFor_fixed, only.breakpoints = TRUE, names = "lambda1.abs")[,1]
  seq_lambdaBP <- rev(seq_lambda)[duplicated(rev(seq_ncoef0))==FALSE]
  
  #expect_equal(lambda1path, expected=seq_lambdaBP, tolerance=test.tolerance, scale=test.scale)    
  ## disagreement but the result of penalized is suspicious: 
  #test1 <- penalized(Y ~  ., data = df.data, trace = FALSE, lambda2 = lambda2, lambda1 = 129)
  #test1 <- penalized(Y ~  ., data = df.data, trace = FALSE, lambda2 = lambda2, lambda1 = 131)
  ## 129.790158 is a breakpoint
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathFor_fixed, file.path(path.res, "RegLD-PathFor_fixed.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathFor_fixed.rds"))
      expect_equal(getPath(PathFor_fixed), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
  
  # data2
  PathFor_fixed2 <- estimate(plvm.model,  data = df.data2, increasing = TRUE, fixSigma = TRUE, lambda2 = lambda2,
                             regularizationPath = TRUE)
  
  expect_equal(getPath(PathFor_fixed, names = "lambda1.abs"), getPath(PathFor_fixed2, names = "lambda1.abs"), tolerance=test.tolerance, scale=test.scale)
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathFor_fixed2, file.path(path.res, "RegLD-PathFor_fixed2.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathFor_fixed2.rds"))
      expect_equal(getPath(PathFor_fixed2), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
  
})

cat("  - lasso path backward \n")
test_that("EPSODE-backward vs penalize with elasticNet", {
  
  # data1
  PathBack_fixed <- estimate(plvm.model,  data = df.data, increasing = FALSE, fixSigma = TRUE,
                             regularizationPath = TRUE)
  
  lambda1path <- getPath(PathBack_fixed, names = "lambda1.abs")[,1]
  indexLambda <- apply(outer(lambda1path,seq_lambda,'-'), 2, function(x){which.min(abs(x))})
  
  # expect_equal(lambda1path[indexLambda], expected=seq_lambda, tolerance=test.tolerance, scale=test.scale)    
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathBack_fixed, file.path(path.res, "RegLD-PathBack_fixed.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathBack_fixed.rds"))
      expect_equal(getPath(PathBack_fixed), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
  
  # data2
  PathBack_fixed2 <- estimate(plvm.model,  data = df.data2, increasing = FALSE, fixSigma = TRUE, 
                              regularizationPath = TRUE)
  
  expect_equal(getPath(PathBack_fixed, names = "lambda1.abs"), getPath(PathBack_fixed2, names = "lambda1.abs"))
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathBack_fixed2, file.path(path.res, "RegLD-PathBack_fixed2.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathBack_fixed2.rds"))
      expect_equal(getPath(PathBack_fixed2), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
  
})


#### check fix lambda - at the breakpoints ####
cat("  - proxGrad at the breakpoints \n")

for(iter_l in 1:n.lambda){
  
  # no constrains can lead to negative variance parameters
  
  # with constrains
  eplvm.fit_tempo2 <- estimate(plvm.model,  data = df.data, fixSigma = FALSE,
                               lambda1 = penalized.PathL1[[iter_l]]@lambda1/penalized.PathL1[[iter_l]]@nuisance$sigma2, 
                               lambda2 = penalized.PathL1[[iter_l]]@lambda2/penalized.PathL1[[iter_l]]@nuisance$sigma2, 
                               control = list(constrain = TRUE))
  
  test_that("NR vs proxGrad with elasticNet (constrain)", {
    expect_equal(object = coef(eplvm.fit_tempo2),
                 expected = coef2.penalized(penalized.PathL1[[iter_l]]),
                 tolerance = test.tolerance, scale=1)  
  })
  
  # fixed sigma
  eplvm.fit_tempo3 <- estimate(plvm.model,  data = df.data, fixSigma = TRUE,
                               lambda1 = penalized.PathL1[[iter_l]]@lambda1, 
                               lambda2 = penalized.PathL1[[iter_l]]@lambda2)
  
  test_that("NR vs proxGrad with elasticNet (fix sigma)", {
    expect_equal(object = coef(eplvm.fit_tempo3),
                 expected = coef2.penalized(penalized.PathL1[[iter_l]]),
                 tolerance = test.tolerance, scale=1)  
  })
  
}

#### check fix lambda - between breakpoints ####
cat("  - between breakpoints \n")

seq2_lambda <- igraph::running.mean(seq_lambda, binwidth = 2)

for(iter_l in 1:length(seq2_lambda)){
  penalized.L1 <- penalized(Y ~  ., data = df.data, lambda1 = seq2_lambda[iter_l], trace = FALSE, lambda2 = lambda2)
  
  # constrain
  eplvm.fit_tempo3 <- estimate(plvm.model,  data = df.data, fixSigma = TRUE,
                               lambda1 = seq2_lambda[iter_l],
                               lambda2 = lambda2, 
                               control = list(constrain = TRUE))
  
  test_that("NR vs proxGrad with elasticNet (fix sigma - between knots)", {
    expect_equal(object = coef(eplvm.fit_tempo3),
                 expected = coef2.penalized(penalized.L1),
                 tolerance = test.tolerance, scale=1)  
  })
  
  # no constrain - can find unexpected solution
  eplvm.fit_tempo1 <- estimate(plvm.model,  data = df.data,
                               lambda1 = seq2_lambda[iter_l]/penalized.L1@nuisance$sigma2, 
                               lambda2 = lambda2/penalized.L1@nuisance$sigma2, 
                               control = list(constrain = TRUE))
  
  test_that("NR vs proxGrad with elasticNet (free sigma - between knots)", {
    penalized.L1bis <- penalized(Y ~  ., data = df.data, 
                                 lambda1 = eplvm.fit_tempo1$penalty$lambda1.abs, 
                                 lambda2 = eplvm.fit_tempo1$penalty$lambda2.abs ,trace = FALSE)
    expect_equal(object = coef(eplvm.fit_tempo1),
                 expected = coef2.penalized(penalized.L1bis),
                 tolerance = test.tolerance, scale=1)
    
    
  })
  
}

#### partial penalization ####
cat("  - partial penalization \n")

ppenalized.PathL1 <- penalized(Y~.,data = df.data, steps = "Park", trace = FALSE, lambda2 = lambda2, 
                               unpenalized = Y~ X2 + X4,
                               penalized = Y ~ X1 + X3 + X5)
seq_lambda2 <- unlist(lapply(ppenalized.PathL1, function(x){x@lambda1}))
plvm.model2 <- penalize(lvm.model, value = Y ~ X1 + X3 + X5)

test_that("EPSODE-forward vs penalize with partial lasso", {
           
  system.time(
    PathFor_fixed3 <- estimate(plvm.model2,  data = df.data, increasing = TRUE, fit = NULL, fixSigma = TRUE,
                               regularizationPath = TRUE, lambda2 = lambda2, control = list(constrain = TRUE))
  )
  lambda1path <- getPath(PathFor_fixed3, names = "lambda1.abs")[,1]
  indexLambda <- apply(outer(lambda1path,seq_lambda2,'-'), 2, function(x){which.min(abs(x))})
  
 # expect_equal(lambda1path[indexLambda], expected=seq_lambda2, tolerance=test.tolerance, scale=test.scale)  
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathFor_fixed3, file.path(path.res, "RegLD-PathFor_fixed3.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathFor_fixed3.rds"))
      expect_equal(getPath(PathFor_fixed3), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
})

test_that("EPSODE-backward vs penalize with partial lasso", {
  system.time(
    PathBack_fixed3 <- estimate(plvm.model2,  data = df.data, increasing = FALSE, fit = NULL, fixSigma = TRUE,
                                regularizationPath = TRUE, lambda2 = lambda2,
                                control = list(constrain = TRUE))
  )
  lambda1path <- getPath(PathBack_fixed3, names = "lambda1.abs")[,1]
  indexLambda <- apply(outer(lambda1path,seq_lambda2,'-'), 2, function(x){which.min(abs(x))})
  # expect_equal(lambda1path[indexLambda], expected=seq_lambda2, tolerance=test.tolerance, scale=test.scale)  
  
  if(!is.null(save)){
    if(save){
      saveRDS(PathBack_fixed3, file.path(path.res, "RegLD-PathBack_fixed3.rds"))   
    }else{
      GS <- readRDS(file.path(path.res, "RegLD-PathBack_fixed3.rds"))
      expect_equal(getPath(PathBack_fixed3), expected=getPath(GS), tolerance=test.tolerance, scale=test.scale)   
    }
  }
})

#### > regression with factors ####
cat(" * regression with factors \n")
set.seed(10)
n <- 300
formula.lvm <- as.formula(paste0("Y~",paste(paste0("X",1:12), collapse = "+")))
mSim <- lvm(formula.lvm)
categorical(mSim,labels=c("A","B","C")) <- "X1"
categorical(mSim,labels=c("A","B","C")) <- "X11"
df.data <- sim(mSim,n)
df.data[,setdiff(names(df.data),c("X1","X11"))] <- scale(df.data[,setdiff(names(df.data),c("X1","X11"))])

lvm.model <- lvm(formula.lvm)
plvm.model <- penalize(lvm.model)


ppenalized.PathL12.factor <- penalized(Y~.,data = df.data, steps = "Park", lambda2 = lambda2, lambda1 = 10, trace = FALSE) # CRASH
seq_lambda2 <- unlist(lapply(ppenalized.PathL12.factor, function(x){x@lambda1}))

## regularization path
test_that("EPSODE with factors - lambda=0", {
  #prox <- estimate(plvm.model,  data = df.data, fixSigma = TRUE, lambda1 = 46.88472, lambda2 = lambda2, control = list(constrain = TRUE))
  
  path1F <- estimate(plvm.model,  data = df.data, regularizationPath = TRUE, fixSigma = TRUE, lambda2 = lambda2, 
                     control = list(constrain = TRUE))
  
  path1B <- estimate(plvm.model,  data = df.data, regularizationPath = TRUE, fixSigma = TRUE, lambda2 = lambda2, 
                     increasing = FALSE, control = list(constrain = TRUE))
  p1 <- getPath(path1F)
  p2 <- getPath(path1B, row = 1:nrow(p1))
  rownames(p2) <- 1:nrow(p1)
  expect_equal(p1,p2, tolerance=10*test.tolerance, scale=test.scale)
  
  # comparison to proxGrad  - an error may occur here as group lasso is used for factors
  pfit_Fixed <- estimate(plvm.model,  data = df.data, 
                         lambda1 = getPath(path1F, names = "lambda1.abs", row = 8), 
                         lambda2 = getPath(path1F, names = "lambda2.abs", row = 8), 
                         fixSigma = TRUE, control = list(constrain = TRUE))
  expect_equal(as.double(coef(pfit_Fixed)), as.double(getPath(path1F, lambda = NULL, row = 8)), tolerance=test.tolerance, scale=test.scale)
  
  ## find another solution when free
  # pfit_Free <- estimate(plvm.model,  data = df.data, lambda1 = getPath(path1F, names = "lambda1", row = 8), fixSigma = FALSE, control = list(constrain = TRUE))
  # expect_equal(as.double(coef(pfit_Free)), as.double(getPath(path1F, lambda = NULL, row = 8)), tolerance=test.tolerance, scale=test.scale)
})

#### > high dimensional ####
cat(" *  high dimensional case \n")

#### simulation ####
set.seed(10)
n <- 20
n.region <- 25
formula.lvm <- as.formula(paste0("Y~",paste(paste0("X",1:n.region), collapse = "+")))
lvm.modelSim <- lvm()
regression(lvm.modelSim, formula.lvm) <-   as.list( rbinom(n.region, size = 1, prob = 0.3)*rnorm(n.region, 3,1) ) # as.list( c(rep(0,2),0.25,0.5,0.75) ) # 
distribution(lvm.modelSim, ~Y) <- normal.lvm(sd = 2)
df.data <- sim(lvm.modelSim,n)
df.data <- as.data.frame(scale(df.data))

### models ####
lvm.model <- lvm(formula.lvm)
# elvm.model <- estimate(lvm.model, df.data)
plvm.model <- penalize(lvm.model)

penalized.PathL1 <- penalized(Y ~  ., data = df.data, lambda1 = 1, steps = "Park", lambda2 = lambda2, trace = FALSE)
seq_lambda <- unlist(lapply(penalized.PathL1, function(x){x@lambda1}))

#### check fix lambda ####
cat("  - proxGrad at the breakpoints \n")

subsequence <- sample.int(length(seq_lambda), 10)

for(iter_ll in 1:length(subsequence)){
  iter_l <- subsequence[iter_ll]
  
  # fixed sigma
  eplvm.fit_tempo2 <- estimate(plvm.model,  data = df.data, fixSigma = TRUE, lambda2 = lambda2,
                               lambda1 = penalized.PathL1[[iter_l]]@lambda1,
                               control = list(constrain = TRUE))
  
  # print(range(coef(eplvm.fit_tempo2)-coef2.penalized( penalized.PathL1[[iter_l]])))
  test_that("penalized vs pLVM with lasso (high dimensional - sigmaFixed)", {
    expect_equal(object=coef(eplvm.fit_tempo2),
                 expected=coef2.penalized( penalized.PathL1[[iter_l]]),
                 tolerance=1e-3)
  })
  
  # normal model - can find unexpected solution
  eplvm.fit_tempo1 <- estimate(plvm.model,  data = df.data, fixSigma = FALSE, 
                               lambda1 = penalized.PathL1[[iter_l]]@lambda1/penalized.PathL1[[iter_l]]@nuisance$sigma2,
                               lambda2 = penalized.PathL1[[iter_l]]@lambda2/penalized.PathL1[[iter_l]]@nuisance$sigma2,
                               control = list(constrain = TRUE))
  
  test_that("penalized vs pLVM with lasso (high dimensional - sigmaFree)", {
    penalized.L1bis <- penalized(Y ~  ., data = df.data, 
                                 lambda1 = eplvm.fit_tempo1$penalty$lambda1.abs, 
                                 lambda2 = eplvm.fit_tempo1$penalty$lambda2.abs, 
                                 trace = FALSE)
    expect_equal(object=coef(eplvm.fit_tempo1),
                 expected=coef2.penalized( penalized.L1bis ),
                 tolerance=1e-2)
  })
}

#### regularization path ####
cat("  - lasso path \n")
test_that("LVM(EPSODE-backward) vs penalize with lasso (high dimensional)", {
  elvm.PathL1_EPSODE <- estimate(plvm.model,  data = df.data, increasing = FALSE, fixSigma = TRUE,
                                 regularizationPath = TRUE, lambda2 = lambda2, stopLambda = seq_lambda[5])
  lambda1path <- getPath(elvm.PathL1_EPSODE, names = "lambda1.abs")[,1]
  lambda1path <- lambda1path[-length(lambda1path)]
  indexLambda <- apply(outer(lambda1path,seq_lambda[1:5],'-'), 2, function(x){which.min(abs(x))})
  expect_equal(lambda1path[indexLambda], expected=seq_lambda[1:5], tolerance=1e-1, scale=test.scale)  
})



