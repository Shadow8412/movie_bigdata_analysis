#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test PySpark Hive connection"""
import os
os.environ['SPARK_HOME'] = '/usr/local/spark'
os.environ['HADOOP_HOME'] = '/usr/local/hadoop'
os.environ['HIVE_HOME'] = '/usr/local/hive'

import sys
sys.path.insert(0, '/usr/local/spark/python')
sys.path.insert(0, '/usr/local/spark/python/lib/py4j-0.10.4-src.zip')

from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Test Hive") \
    .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \
    .enableHiveSupport() \
    .getOrCreate()

spark.sql("USE movie_db")
print("=== Tables ===")
spark.sql("SHOW TABLES").show()

print("=== Ratings count ===")
spark.sql("SELECT COUNT(*) FROM ratings").show()

print("=== Sample movies ===")
spark.sql("SELECT * FROM movies LIMIT 5").show(truncate=False)

spark.stop()
print("Spark Hive connection OK!")
