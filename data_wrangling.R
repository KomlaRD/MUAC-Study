# Load packages
pacman::p_load(
  tidyverse, # Wrangling
  rio, # Import and export data
  here, # File management
  skimr, # Skim dataset
  finalfit, # Labeling
  janitor, # Clean names
  DataExplorer # Data exploration
)


# Import dataset
df <- import(here("data", "muac_data.csv"))

# Clean names
df <- clean_names(df)

# Remove redundant columns and meta-data
df <- df |>
  select(-c(
    start,
    end,
    participant_id,
    sex_2,
    id,
    uuid,
    submission_time,
    validation_status,
    notes,
    status,
    submitted_by,
    version,
    tags,
    index
  ))

# Clean data (Full dataset: 389)
## Remove participant with wrongly entered age, height, missing sex and weight
df <- df |> filter(age != "Option 2")

## Remove participant with missing height and weight
df <-  df[-91,]

## Remove participant with missing age
df <-  df[-159,]

## Correct participant with height recorded as 69.0 instead of 169.0
df$height_2[df$height_2 == 69.0] <- 169.0

# Convert height_1 to numeric
df$height_1 <- as.numeric(df$height_1)

# Convert age to numeric
df$age <- as.numeric(df$age)

# Mutate variables (Average values for double measurements)
df <- df |>
  mutate(
    height = (height_1 + height_2) / 2, # Height (cm)
    weight = (weight_1 + weight_2) / 2, # Weight (cm)
    cc = (calf_circumference_1 + calf_circumference_2) / 2, # Calf circumference (cm)
    muac = (muac_1 + muac_2) / 2 # Mid-upper arm circumference (cm)
  )

# Remove measurement variables
df <- df |>
  select(-c(
    height_1,
    height_2,
    weight_1,
    weight_2,
    muac_1,
    muac_2,
    calf_circumference_1,
    calf_circumference_2
  ))


# Mutate categorical variables
df <- df |> 
  mutate(
    # Sex
    sex = factor(sex) |> ff_label("Sex"),
    
    # Religion
    religion = factor(religion) |> ff_label("Religion"),
    
    # Educational level
    education_level = factor(education_level) |> ff_label("Educational level"),
    
    # Employment status
    employment = factor(employment) |> ff_label("Employment status")
  )


# Label numeric variables
df <- df |>
  mutate(
    bmi = (weight / (height/100) **2),
    age = ff_label(age, "Age (years"),
    height = ff_label(height, "Height (cm)"),
    weight = ff_label(weight, "Weight (kg)"),
    cc = ff_label(cc, "Calf circumference (cm)"),
    muac = ff_label(muac, "MUAC (cm)"),
    bmi = ff_label(bmi, "Body mass index (kgm-2")
  )

# Mutate bmi into categories
df <- df |>
  mutate(
    bmi_cat = case_when(
      bmi < 18.5 ~ "Underweight",
      bmi >= 18.5 & bmi <= 24.9 ~ "Normal",
      bmi >= 25.0 & bmi <= 29.9 ~ "Overweight",
      bmi >= 30.0 ~ "Obese"
    ) |> ff_label("BMI categories"),
    bmi_cat = factor(bmi_cat)
  )
    
# Skim dataset
skim(df)

# Shapiro-Wilk test
# Function to perform Shapiro-Wilk test and extract p-value
shapiro_test <- function(x) {
  shapiro_result <- shapiro.test(x)
  return(shapiro_result$p.value)
}

# Extract numeric variables from the dataset
numeric_vars <- df %>%
  select_if(is.numeric)

# Apply the Shapiro-Wilk test to each numeric variable and tidy the results
shapiro_p_values <- numeric_vars %>%
  summarise(across(everything(), ~ shapiro_test(.))) %>%
  pivot_longer(everything(), names_to = "Variable", values_to = "P_Value")

# Display the p-values
print("Shapiro values for normality testing")
print(shapiro_p_values)

## Note; None of the numeric variables are normally distributed

## Predict weight (trial)

df$predicted_weight <- ifelse(df$sex == "Male",
                              -60.3 + (2.26 * df$muac) + (0.72) + (0.33 * df$height),
                              -60.3 + (2.26 * df$muac) + (0.33 * df$height)) 


# Evaluate weight performance
# Function to evaluate model predictions
weight_metrics <- function(weight, predicted_wt){
  # Mean absolute error
  mae_eval <- Metrics::mae(weight, predicted_wt)

  # Mean squared error
  mse_eval <- Metrics::mse(weight, predicted_wt)

  # Root mean squared error
  rmse_eval <- Metrics::rmse(weight, predicted_wt)

  return(c(mae_eval, mse_eval, rmse_eval))
}

weight_metrics(df$weight, df$predicted_wt) # mae, mse, rmse

# Weight features
weight_features <- df |> 
  select(-c(weight, bmi, bmi_cat))

# BMI features
bmi_features <- df |>
  select(-c(bmi, bmi_cat))

# Create exploratory data analysis report
create_report(df)

## Export dataset
export(df, here("data", "muac.csv"))
