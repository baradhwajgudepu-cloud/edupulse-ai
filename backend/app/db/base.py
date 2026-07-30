import re
from sqlalchemy.orm import DeclarativeBase, declared_attr

def camel_to_snake(name: str) -> str:
    """
    Converts PascalCase to snake_case.
    """
    s1 = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

def pluralize(name: str) -> str:
    """
    Applies basic pluralization rules for database table names.
    """
    if name.endswith('y'):
        # Check if the letter before 'y' is a consonant (e.g., category -> categories)
        if len(name) > 1 and name[-2] not in 'aeiou':
            return name[:-1] + 'ies'
    if name.endswith(('s', 'x', 'z', 'ch', 'sh')):
        return name + 'es'
    return name + 's'

class Base(DeclarativeBase):
    """
    SQLAlchemy Declarative Base.
    Configures standard naming conventions for metadata and table naming.
    """
    @declared_attr.directive
    def __tablename__(cls) -> str:
        snake_name = camel_to_snake(cls.__name__)
        return pluralize(snake_name)

# Base declarative base model class definition. Models will be imported in env.py for Alembic or in app routers for application initialization.
