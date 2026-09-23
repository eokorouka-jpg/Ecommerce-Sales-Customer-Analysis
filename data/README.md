# Dataset

## Source

This project uses the **Online Retail** dataset from the UCI Machine Learning Repository.

- Dataset: Online Retail
- Source: UCI Machine Learning Repository
- Original dataset size: 541,909 transactions
- Time period: 1 December 2010 to 9 December 2011
- Dataset page: https://archive.ics.uci.edu/dataset/352/online+retail

## Dataset Description

The dataset contains transactional data from a UK-based non-store online retailer. The company primarily sells unique all-occasion gifts, and many of its customers are wholesalers.

The original dataset contains the following fields:

- InvoiceNo
- StockCode
- Description
- Quantity
- InvoiceDate
- UnitPrice
- CustomerID
- Country

Invoice numbers beginning with **C** represent cancellations.

## Data Usage

The original Excel dataset is not included in this repository due to its size.

The data was cleaned and transformed in Python before being used for analysis in MySQL and Power BI.

The analysis separates valid positive sales transactions from cancellation transactions so that sales performance and cancellation exposure can be analysed independently.

## License and Attribution

The Online Retail dataset is provided through the UCI Machine Learning Repository and is licensed under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** license.

Source: UCI Machine Learning Repository — Online Retail dataset.
