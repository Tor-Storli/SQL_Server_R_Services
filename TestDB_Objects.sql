USE [TestDB]
GO
/****** Object:  Table [dbo].[STOCK_PIVOT]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[STOCK_PIVOT](
	[date] [date] NULL,
	[SP500] [float] NULL,
	[ABT] [float] NULL,
	[ABBV] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[STOCKS]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[STOCKS](
	[Date] [date] NULL,
	[Ticker] [varchar](50) NULL,
	[Open] [float] NULL,
	[High] [float] NULL,
	[Low] [float] NULL,
	[Close] [float] NULL,
	[Volume] [float] NULL,
	[Adjusted] [float] NULL,
	[Return] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[Get_PA_ANNUAL_RET]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_PA_ANNUAL_RET](@Symbol varchar(50))
	 AS
	 BEGIN
     SET NOCOUNT ON;
 DECLARE @sql NVARCHAR(MAX);
 SET @sql = N'SELECT [Date] as [date]
				  ,[Ticker] 
				  ,[Adjusted] as [adjusted]
			  FROM [TestDB].[dbo].[STOCKS]
			  WHERE [Ticker] = @Ticker
			  ORDER BY Date Asc;';

DECLARE @rScript nvarchar(max)
SET @rScript = N'library(tidyquant)
                 data <- SqlData;

				 Ra <- data %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Ra")

				# Get Stats table from PerformanceAnalytics
				annret <- Ra %>%
					      tq_performance(Ra = Ra, Rb = NULL, performance_fun = table.AnnualizedReturns)

                OutData <- annret';
EXEC sp_execute_external_script
     @language = N'R',
     @script = @rscript,
     @input_data_1 = @sql,
	 @input_data_1_name = N'SqlData',
	 @output_data_1_name = N'OutData',
     @params = N'@Ticker Varchar(50)',
     @Ticker = @Symbol

WITH RESULT SETS( 
	   ( [Symbol] varchar(50),
        [AnnualizedReturn] float,
        [AnnualizedSharpe(Rf=0%)] float,
        [AnnualizedStdDev] float
       )
	   ); 
END
GO
/****** Object:  StoredProcedure [dbo].[Get_PA_CAPM]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_PA_CAPM]
	 AS
	 BEGIN
     SET NOCOUNT ON;
 DECLARE @sql NVARCHAR(MAX);
 SET @sql = N'SELECT [Date] as [date]
				  ,[Ticker] 
				  ,[Adjusted] as [adjusted]
			  FROM [TestDB].[dbo].[STOCKS]
			  WHERE [Ticker] IN(''^GSPC'',''ABBV'',''ABT'')
			  ORDER BY [Ticker], Date Asc;';

DECLARE @rScript nvarchar(max)
SET @rScript = N'library(tidyquant)
                 data <- SqlData;

				 Ra <- data %>%
				       filter(Ticker != ''^GSPC'') %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Ra")

				 # Get returns for SP500 as baseline
				 Rb <- data %>%
				       filter(Ticker == ''^GSPC'') %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Rb")

				# Merge stock returns with baseline
				RaRb <- left_join(Ra, Rb, by = c("date" = "date"))

				# Get CAPM table from PerformanceAnalytics
				capm <- RaRb %>%
					      tq_performance(Ra = Ra, Rb = Rb, performance_fun = table.CAPM)

                OutData <- capm';
EXEC sp_execute_external_script
     @language = N'R',
     @script = @rscript,
     @input_data_1 = @sql,
	 @input_data_1_name = N'SqlData',
	 @output_data_1_name = N'OutData'
WITH RESULT SETS( 
	   ([symbol] nvarchar(50), [ActivePremium] float, [Alpha] float, [AnnualizedAlpha] float,[Beta] float,
		[Beta_Minus] float,[Beta_Plus] float,[Correlation] float,[Correlationp_value] float,[InformationRatio] float,
		[R_squared] float, [TrackingError] float,[TreynorRatio] float)
	   ); 
END
GO
/****** Object:  StoredProcedure [dbo].[Get_PA_CORR]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_PA_CORR]
	 AS
	 BEGIN
     SET NOCOUNT ON;
 DECLARE @sql NVARCHAR(MAX);
 SET @sql = N'SELECT [Date] as [date]
				  ,[Ticker] 
				  ,[Adjusted] as [adjusted]
			  FROM [TestDB].[dbo].[STOCKS]
			  WHERE [Ticker] IN(''^GSPC'',''ABBV'',''ABT'')
			  ORDER BY [Ticker], Date Asc;';

DECLARE @rScript nvarchar(max)
SET @rScript = N'library(tidyquant)
                 data <- SqlData;

				 Ra <- data %>%
				       filter(Ticker != ''^GSPC'') %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Ra")

				 # Get returns for SP500 as baseline
				 Rb <- data %>%
				       filter(Ticker == ''^GSPC'') %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Rb")

				# Merge stock returns with baseline
				RaRb <- left_join(Ra, Rb, by = c("date" = "date"))

				# Get Stats table from PerformanceAnalytics
				corr <- RaRb %>%
					      tq_performance(Ra = Ra, Rb = Rb, performance_fun = table.Correlation)

                OutData <- corr[,c(1,3)]';
EXEC sp_execute_external_script
     @language = N'R',
     @script = @rscript,
     @input_data_1 = @sql,
	 @input_data_1_name = N'SqlData',
	 @output_data_1_name = N'OutData'

WITH RESULT SETS( 
	   ( [Symbol] varchar(50),
        [Correlation_to_SP500] float 
       )
	   ); 
END
GO
/****** Object:  StoredProcedure [dbo].[Get_PA_STATS]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_PA_STATS]
	 AS
	 BEGIN
     SET NOCOUNT ON;
 DECLARE @sql NVARCHAR(MAX);
 SET @sql = N'SELECT [Date] as [date]
				  ,[Ticker] 
				  ,[Adjusted] as [adjusted]
			  FROM [TestDB].[dbo].[STOCKS]
			  WHERE [Ticker] IN(''^GSPC'',''ABBV'',''ABT'')
			  ORDER BY [Ticker], Date Asc;';

DECLARE @rScript nvarchar(max)
SET @rScript = N'library(tidyquant)
                 data <- SqlData;

				 Ra <- data %>%
				      # filter(Ticker != ''^GSPC'') %>%
				         group_by(Ticker) %>%
				         tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Ra")

				 # Get returns for SP500 as baseline
				# Rb <- data %>%
				    #   filter(Ticker == ''^GSPC'') %>%
				    #     group_by(Ticker) %>%
				    #     tq_transmute(adjusted, periodReturn, period = "daily", col_rename = "Rb")

				# Merge stock returns with baseline
				#RaRb <- left_join(Ra, Rb, by = c("date" = "date"))

				# Get Stats table from PerformanceAnalytics
				stats <- Ra %>%
					      tq_performance(Ra = Ra, Rb = NULL, performance_fun = table.Stats)

                OutData <- stats';
EXEC sp_execute_external_script
     @language = N'R',
     @script = @rscript,
     @input_data_1 = @sql,
	 @input_data_1_name = N'SqlData',
	 @output_data_1_name = N'OutData'

WITH RESULT SETS( 
	   ( [Symbol] varchar(50),
        [Observations] float,
        [NAs] float,
        [Minimum] float,
        [Quartile] float,
        [Median] float,
        [Arithmetic_Mean] float,
        [Geometric_Mean] float,
        [Quartile] float,
        [Maximum] float,
        [SE_Mean] float,
        [LCL_Mean_95Pct] float,
        [UCL_Mean_95Pct] float,
        [Variance] float,
        [Stdev] float,
        [Skewness] float,
        [Kurtosis] float
       )
	   ); 
END
GO
/****** Object:  StoredProcedure [dbo].[PA_ReturnChart]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	 CREATE PROCEDURE [dbo].[PA_ReturnChart]
	 AS
	 BEGIN
     SET NOCOUNT ON;
	 DECLARE @sql NVARCHAR(MAX);
	 SET @sql = N'SELECT [Date] as [date]
					    ,[Ticker] as [symbol]
				        ,[Adjusted] as [adjusted]
			  FROM [TestDB].[dbo].[STOCKS]
			  WHERE [Ticker] IN(''^GSPC'',''ABBV'',''ABT'')
			  ORDER BY [Ticker], Date Asc;';

	 DECLARE @rScript nvarchar(max)
	 SET @rScript = N'
				library(quantmod)
				library(PerformanceAnalytics)

				# Look up data for SP500, Janus Fund, and Janus Research Fund
				# -----------------------------------------------------------
				Tickers <- c(''^GSPC'',''JANDX'',''JNRFX'')

				## original  dat <- getSymbols(Tickers,src="yahoo", from="2013-01-01", to="2020-02-26")
				dat <- getSymbols(Tickers,src="yahoo", from="2013-01-01", to="2020-02-26")
				
				# ===========================================
				#   Calculate Monthley Returns - quantmod
				# ===========================================
				SP500.Ret <- monthlyReturn(GSPC)
				JANDX.Ret <- monthlyReturn(JANDX)
				JNRFX.Ret <- monthlyReturn(JNRFX)

				names(SP500.Ret)="SP500"
				names(JANDX.Ret)="JANDX"
				names(JNRFX.Ret)="JNRFX"

				retAll <- data.frame(SP500.Ret,JANDX.Ret,JNRFX.Ret)

				# set up report file for chart
				 image_file = tempfile();  
				 jpeg(filename = image_file, width = 400, height = 400);

				par(mfrow=c(1,1))
				chart.CumReturns(retAll,main="Cumulative Returns",legend.loc="topleft")
				chart.CumReturns(retAll,wealth.index=TRUE, main="Growth of $1",legend.loc="topleft")

                dev.off();

			    OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))';
	--INSERT INTO [dbo].[Plots]
	EXEC sp_execute_external_script
		 @language = N'R',
		 @script = @rscript,
		 @input_data_1 = @sql,
		 @input_data_1_name = N'SqlData'
	WITH RESULT SETS ((plotme varbinary(max))); 
	END


	/*

	EXEC [dbo].[PA_ReturnChart]

	*/
GO
/****** Object:  StoredProcedure [dbo].[sp_Box_Plot]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[sp_Box_Plot]
  AS
  BEGIN
   --Insert INTO dbo.plots(plot) 
		EXEC sp_execute_external_script
		 @language = N'R'
		 ,@script = N'
		  df <- InputDataSet 
		  image_file <- tempfile()
		  jpeg(filename = image_file, width = 400, height = 400)
		  input <- mtcars[,c(''mpg'',''cyl'')]

		  boxplot(mpg ~ cyl, data = mtcars, xlab = "Number of Cylinders",
				ylab = "Miles Per Gallon", main = "Mileage Data")
		  dev.off()
		  OutputDataSet <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))'
       
   WITH RESULT SETS ((plotty varbinary(max))); 
END
GO
/****** Object:  StoredProcedure [dbo].[sp_PDF]    Script Date: 3/20/2020 9:08:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
	CREATE PROCEDURE [dbo].[sp_PDF]
  AS
  BEGIN
     DECLARE @sql NVARCHAR(MAX);
	 SET @sql = N'SELECT  [date]
                    ,[SP500]
                    ,[ABT]
                    ,[ABBV]
                FROM [TestDB].[dbo].[STOCK_PIVOT]
			    ORDER BY  [date] Asc';

	 DECLARE @rScript nvarchar(max)
	 SET @rScript = N'library(tidyquant)
                      library(gridExtra)
                      library(grid)
                      
          data <- SqlData;

          data$date <- as.POSIXct(data$date, format="%Y-%m-%d", tz="GMT")
         
          rownames(data) <- data$date
          
          Portfolio <- data %>%
                select(SP500,ABT,ABBV)

          Portfolio_xts <- as.xts(Portfolio)
          
	      image_file = tempfile();  
          pdf(image_file,width=1000, height= 800, paper="USr") 
  
          chart.RiskReturnScatter(Portfolio_xts, Rf=0, main = "Risk return Plot", add.sharpe = c(1,2,3))

          dev.off();
          
          plots_df <- data.frame(data=readBin(file(image_file, "rb"), what=raw(), n=1e6))

		  OutputDataSet <- plots_df' 

   EXEC sp_execute_external_script
		 @language = N'R',
		 @script = @rscript,
		 @input_data_1 = @sql,
		 @input_data_1_name = N'SqlData'
	WITH RESULT SETS ((plotme varbinary(max))); 
	END


	/*

	EXEC [dbo].[sp_PDF]

	*/
GO
