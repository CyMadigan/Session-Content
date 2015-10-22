﻿## 1. Define all of my objects --these are the modules
## Garage,Car,Transmission

## 2. Define the hierarchy --like "inheritance"
## (Parent module) Garage --> Car (child module) --> Transmission (child module)

## 3. Define the object "methods"
## Use CRUD -- New/Get/Set/Remove as a minimum -- common "methods" so "objects" can interact with each other

## 4. Define properties for each "object". These will be the function parameters
## ie. A car has a Make, Model and Year and ALWAYS will --mandatory
## ie. A transmission has a type: Automatic or Manual --mandatory but could have different speed --optional

## 4. Define how the objects will interact

## This is expected
## New-Garage | New-Car -Param1 -Param2 | Set-Car -Param1 -PassThru | New-Transmission -Param1 -Param2

## This is NOT expected to happen
## New-Transmission -Param1 -Param2 | New-Garage

## How I design modules/functions
start https://www.gliffy.com/go/html5/9231857?app=1b5094b0-6042-11e2-bcfd-0800200c9a66

## Garage module with manifest in my module path
Get-Childitem -Path "$($env:PSModulePath.Split(';')[0])\Garage"

## By defining NestedModules you can sorta/kinda replicate inheritance
Invoke-Item "$($env:PSModulePath.Split(';')[0])\Garage\Garage.psd1"

Import-Module Garage
Get-Command -Module Garage


$garageParams = @{
	'Address' = '8671 Ash St.'
	'Capacity' = 10
	'FloorType' = 'Concrete'
	'AirConditioned' = $true
}

$carParams = @{
	'Make' = 'BMW'
	'Model' = '328i'
	'Year' = 2015
	'VIN' = '1234567'
}

$transParams = @{
	'SerialNumber' = '12345789333'
	'Type' = 'Automatic'
	'Speed' = 5
}

## Build objects hierarchially
New-Garage @garageParams | New-Car @carParams | New-Transmission @transParams

Get-Car -VIN 1234567
Get-Car -VIN 1234567 | Get-Transmission

Get-Car -VIN 1234567 | Set-Car -Make BMW -PassThru | Get-Transmission