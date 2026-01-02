"""
SMARTCARE+ Nutrition Service Models

Food recognition, USDA API integration, and meal planning.
"""

from .usda_client import (
    USDAClient,
    LocalFoodDatabase,
    FoodItem,
    NutrientInfo,
    get_usda_client,
    get_local_food_db
)

from .meal_planner import (
    MealPlanGenerator,
    MealLogger,
    MealType,
    MealItem,
    Meal,
    DailyMealPlan,
    MealLog,
    RDAProfile,
    DietaryRestriction,
    get_meal_plan_generator,
    get_meal_logger
)

__all__ = [
    # USDA Client
    "USDAClient",
    "LocalFoodDatabase", 
    "FoodItem",
    "NutrientInfo",
    "get_usda_client",
    "get_local_food_db",
    # Meal Planner
    "MealPlanGenerator",
    "MealLogger",
    "MealType",
    "MealItem",
    "Meal",
    "DailyMealPlan",
    "MealLog",
    "RDAProfile",
    "DietaryRestriction",
    "get_meal_plan_generator",
    "get_meal_logger",
]
