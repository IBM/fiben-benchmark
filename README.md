# FIBEN Benchmark

## FIBEN SCHEMA
FIBEN is a Natural Language Querying benchmark, with a dataset that emulates a real-world data mart. The FIBEN schema models information about public companies, their officers, and financial metrics reported over a period of time. Users can ask queries about the financial health and performance of public companies in a variety of different industry sectors. The FIBEN schema also describes financial transactions over holdings and securities provided by public companies. Each financial transaction is linked to a customer account. The customer account describes the customer’s portfolio in terms of the securities held, and is associated with the buying or selling of securities such as stocks, bonds and mutual funds of publicly traded companies in different financial markets over a period of time. 

The FIBEN schema conforms to a union of two subsets from two standard finance ontologies: Finance Industry Business Ontology (FIBO) [1] and Finance Report Ontology (FRO) [2]. FIBO is the de-facto industry standard defined by the enterprise data management (EDM) council to represent business concepts and information in the finance domain. FRO is a formal report ontology of an XBRL based financial report which captures the financial metric data reported by public companies to SEC. 

## FIBEN QUERIES
FIBEN is a benchmark for testing NLQ of analytical queries, which may include joins and different types of nested queries[3]. The benchmark consists of 300 NL queries, along with their equivalent SQL queries expressed over FIBEN Schema. For the 300 NL queries, there are 237 distinct target SQL queries. The benchmark query suite includes a mix of 130 single SQL-block queries, and 170 nested queries. Of the nested queries, 28 are of Type-N, 64 of Type-A, 40 of Type-J, 38 from Type-JA as classified following the same definition provided in [3]. The benchmark query suite is provided in FIBEN_Queries.json file in a JSON format with the following keys:

uniqueQueryID: a number that uniquely identifies a unique SQL query.

question: natural language question/user utterance

isParaphrased: True/False. If true, then there is another paraphrasing of the NL query that has the same target SQL query, and the  "uniqueQueryID" points to the entry with the target SQL.
queryType: (non-nested/type-n/type-a/type-j/type-ja)


## Repository Info
This repo contains the following
1. DDL file for creating the FIBEN schema, including FK-PK constraints, compatible with DB2 and PostGreSQL database(FIBEN.sql).
2. Set of natural language benchmark queries and their corresponding SQL queries (FIBEN_Queries.json).
3. Related Documents folder includes publications related to the FIBEN Benchmark.


# References

[1] FIBO. https://spec.edmcouncil.org/fibo/ (July, 2020).

[2] FRO. http://xbrl.squarespace.com/financial-report-ontology/ (Jul, 2020).

[3] Won Kim, "On optimizing an SQL-like nested query", ACM Transactions on Database Systems Volume 7, Issue 3, pp. 443–469.

