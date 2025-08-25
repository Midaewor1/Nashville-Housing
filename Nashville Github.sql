-- ===========================================
-- Nashville Housing Data Cleaning with SQL
-- ===========================================
-- Steps performed in this script:
-- 1. Standardize Date Format
-- 2. Populate NULL Property Addresses
-- 3. Break Out Address into Individual Columns
-- 4. Normalize "SoldAsVacant" Field
-- 5. Remove Duplicate Records
-- 6. Drop Unused Columns

-- Preview the raw data
SELECT * FROM nashvillehousing;


-- ===========================================
-- 1. Standardize Date Format
-- ===========================================

-- 1a. Preview SaleDate conversion into proper DATE type
SELECT SaleDate,
       CAST(SaleDate AS DATE) AS ConvertedDate
FROM nashvillehousing;

-- 1b. Update SaleDate column with proper DATE format
UPDATE nashvillehousing
SET SaleDate = CAST(SaleDate AS DATE)
WHERE SaleDate IS NOT NULL;

-- 1c. Add a new standardized column for clean dates
ALTER TABLE nashvillehousing ADD COLUMN SaleDate_converted DATE;

-- 1d. Populate the new standardized column
UPDATE nashvillehousing
SET SaleDate_new = CAST(SaleDate AS DATE);


-- ===========================================
-- 2. Populate NULL Property Addresses
-- ===========================================

-- 2a. Find rows where PropertyAddress is missing
SELECT *
FROM nashvillehousing
WHERE PropertyAddress IS NULL
ORDER BY ParcelID;

-- 2b. Compare ParcelIDs to pull addresses from matching rows
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, 
       IFNULL(a.PropertyAddress, b.PropertyAddress) AS FilledAddress
FROM nashvillehousing a 
JOIN nashvillehousing b
  ON a.ParcelID = b.ParcelID
 AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- 2c. Update missing PropertyAddress values with matches
UPDATE nashvillehousing a
JOIN nashvillehousing b
    ON a.ParcelID = b.ParcelID
   AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress, b.PropertyAddress)
WHERE a.PropertyAddress IS NULL;


-- ===========================================
-- 3. Break Out Address into Individual Columns
-- ===========================================

-- 3a. Inspect PropertyAddress values
SELECT PropertyAddress
FROM nashvillehousing;

-- 3b. Test splitting PropertyAddress into street + city
SELECT 
    SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) - 1) AS StreetAddress,
    SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1 )   AS City
FROM nashvillehousing;

-- 3c. Add new columns for split PropertyAddress
ALTER TABLE nashvillehousing ADD COLUMN PropertySplitAddress VARCHAR(255);
ALTER TABLE nashvillehousing ADD COLUMN PropertySplitCity VARCHAR(255);

-- 3d. Populate new Property split columns
UPDATE nashvillehousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) - 1);

UPDATE nashvillehousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1);

-- 3e. Check results
SELECT * 
FROM nashvillehousing;

-- 3f. Do the same split for OwnerAddress into Address, City, State
SELECT OwnerAddress
FROM nashvillehousing;

ALTER TABLE nashvillehousing 
ADD COLUMN OwnerSplitAddress VARCHAR(255),
ADD COLUMN OwnerSplitCity VARCHAR(255),
ADD COLUMN OwnerSplitState VARCHAR(255);

-- 3g. Populate Owner split columns
UPDATE nashvillehousing
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ',', 1);

UPDATE nashvillehousing
SET OwnerSplitCity = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1));

UPDATE nashvillehousing
SET OwnerSplitState = TRIM(SUBSTRING_INDEX(OwnerAddress, ',', -1));

-- 3h. Verify Owner split results
SELECT *
FROM nashvillehousing;


-- ===========================================
-- 4. Normalize "SoldAsVacant" Field
-- ===========================================

-- 4a. Inspect distinct values in SoldAsVacant
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM nashvillehousing
GROUP BY SoldAsVacant
ORDER BY 2;

-- 4b. Preview conversion: change Y/N to Yes/No
SELECT SoldAsVacant,
       CASE 
           WHEN SoldAsVacant = 'Y' THEN 'Yes'
           WHEN SoldAsVacant = 'N' THEN 'No'
           ELSE SoldAsVacant
       END AS CleanedValue
FROM nashvillehousing;

-- 4c. Apply updates directly to SoldAsVacant
UPDATE nashvillehousing
SET SoldAsVacant =
    CASE 
        WHEN SoldAsVacant = 'Y' THEN 'Yes'
        WHEN SoldAsVacant = 'N' THEN 'No'
        ELSE SoldAsVacant
    END;


-- ===========================================
-- 5. Remove Duplicate Records
-- ===========================================

-- 5a. Create CTE to assign row numbers for duplicates
WITH RowNumCTE AS (
    SELECT UniqueID,
           ROW_NUMBER() OVER (
               PARTITION BY ParcelID,
                            PropertyAddress,
                            SalePrice,
                            SaleDate,
                            LegalReference
               ORDER BY UniqueID
           ) AS row_num
    FROM nashvillehousing
)

-- 5b. Delete rows where row_num > 1, keeping only first occurrence
DELETE nh
FROM nashvillehousing nh
JOIN RowNumCTE cte ON nh.UniqueID = cte.UniqueID
WHERE cte.row_num > 1;


-- ===========================================
-- 6. Drop Unused Columns
-- ===========================================

-- 6a. Drop redundant address columns
ALTER TABLE nashvillehousing
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress;

-- 6b. Drop old SaleDate column after standardization
ALTER TABLE nashvillehousing
DROP COLUMN SaleDate;
