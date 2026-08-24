"""create communication tables

Revision ID: 3da58b9f1d0c
Revises: 3da58b9f1d0b
Create Date: 2026-08-19 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid

# revision identifiers, used by Alembic.
revision: str = '3da58b9f1d0c'
down_revision: Union[str, None] = '3da58b9f1d0b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create communication_requests table
    op.create_table(
        'communication_requests',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('student_id', sa.Uuid(), nullable=False),
        sa.Column('creator_id', sa.Uuid(), nullable=False),
        sa.Column('assigned_to_id', sa.Uuid(), nullable=True),
        sa.Column('recipient_type', sa.Enum('CLASS_TEACHER', 'PRINCIPAL', 'TEACHER', 'PARENT', name='recipienttype'), nullable=False),
        sa.Column('category', sa.Enum('ATTENDANCE', 'ACADEMIC', 'FEES', 'TRANSPORT', 'LEAVE', 'EXAMINATION', 'REPORT_CARD', 'HOMEWORK', 'BEHAVIOUR', 'HEALTH', 'GENERAL', 'OTHER', name='requestcategory'), nullable=False),
        sa.Column('module', sa.Enum('ATTENDANCE', 'ACADEMIC', 'FEES', 'RESULTS', 'REPORT_CARD', 'LEAVE', 'GENERAL', name='communicationmodule'), nullable=True),
        sa.Column('reference_type', sa.String(length=100), nullable=True),
        sa.Column('reference_id', sa.String(length=100), nullable=True),
        sa.Column('subject', sa.String(length=200), nullable=False),
        sa.Column('priority', sa.Enum('LOW', 'NORMAL', 'HIGH', 'URGENT', name='requestpriority'), nullable=False),
        sa.Column('status', sa.Enum('OPEN', 'ACKNOWLEDGED', 'IN_PROGRESS', 'WAITING_FOR_PARENT', 'ESCALATED', 'PRINCIPAL_REVIEW', 'RESOLVED', 'REOPENED', name='requeststatus'), nullable=False, server_default='OPEN'),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['creator_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['assigned_to_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )

    # Indexes for communication_requests
    op.create_index(op.f('ix_communication_requests_id'), 'communication_requests', ['id'], unique=False)
    op.create_index(op.f('ix_communication_requests_tenant_id'), 'communication_requests', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_communication_requests_school_id'), 'communication_requests', ['school_id'], unique=False)
    op.create_index(op.f('ix_communication_requests_student_id'), 'communication_requests', ['student_id'], unique=False)
    op.create_index(op.f('ix_communication_requests_creator_id'), 'communication_requests', ['creator_id'], unique=False)
    op.create_index(op.f('ix_communication_requests_assigned_to_id'), 'communication_requests', ['assigned_to_id'], unique=False)
    op.create_index(op.f('ix_communication_requests_category'), 'communication_requests', ['category'], unique=False)
    op.create_index(op.f('ix_communication_requests_module'), 'communication_requests', ['module'], unique=False)
    op.create_index(op.f('ix_communication_requests_status'), 'communication_requests', ['status'], unique=False)
    op.create_index(op.f('ix_communication_requests_priority'), 'communication_requests', ['priority'], unique=False)

    # 2. Create communication_participants table
    op.create_table(
        'communication_participants',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('request_id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('last_read_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['request_id'], ['communication_requests.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_index(op.f('ix_communication_participants_id'), 'communication_participants', ['id'], unique=False)
    op.create_index(op.f('ix_communication_participants_tenant_id'), 'communication_participants', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_communication_participants_school_id'), 'communication_participants', ['school_id'], unique=False)
    op.create_index(op.f('ix_communication_participants_request_id'), 'communication_participants', ['request_id'], unique=False)
    op.create_index(op.f('ix_communication_participants_user_id'), 'communication_participants', ['user_id'], unique=False)

    # 3. Create communication_messages table
    op.create_table(
        'communication_messages',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('request_id', sa.Uuid(), nullable=False),
        sa.Column('sender_id', sa.Uuid(), nullable=False),
        sa.Column('sender_role', sa.String(length=50), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['request_id'], ['communication_requests.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['sender_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_index(op.f('ix_communication_messages_id'), 'communication_messages', ['id'], unique=False)
    op.create_index(op.f('ix_communication_messages_tenant_id'), 'communication_messages', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_communication_messages_school_id'), 'communication_messages', ['school_id'], unique=False)
    op.create_index(op.f('ix_communication_messages_request_id'), 'communication_messages', ['request_id'], unique=False)
    op.create_index(op.f('ix_communication_messages_sender_id'), 'communication_messages', ['sender_id'], unique=False)

    # 4. Create communication_attachments table
    op.create_table(
        'communication_attachments',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('message_id', sa.Uuid(), nullable=False),
        sa.Column('file_name', sa.String(length=255), nullable=False),
        sa.Column('file_type', sa.String(length=100), nullable=False),
        sa.Column('file_size', sa.Integer(), nullable=False),
        sa.Column('file_url', sa.String(length=500), nullable=False),
        sa.Column('uploaded_by_id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['message_id'], ['communication_messages.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['uploaded_by_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_index(op.f('ix_communication_attachments_id'), 'communication_attachments', ['id'], unique=False)
    op.create_index(op.f('ix_communication_attachments_message_id'), 'communication_attachments', ['message_id'], unique=False)

    # 5. Create communication_audit_logs table
    op.create_table(
        'communication_audit_logs',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('request_id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('action', sa.String(length=100), nullable=False),
        sa.Column('details', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['request_id'], ['communication_requests.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_index(op.f('ix_communication_audit_logs_id'), 'communication_audit_logs', ['id'], unique=False)
    op.create_index(op.f('ix_communication_audit_logs_request_id'), 'communication_audit_logs', ['request_id'], unique=False)
    op.create_index(op.f('ix_communication_audit_logs_user_id'), 'communication_audit_logs', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_table('communication_audit_logs')
    op.drop_table('communication_attachments')
    op.drop_table('communication_messages')
    op.drop_table('communication_participants')
    op.drop_table('communication_requests')

    # Drop custom enums
    sa.Enum(name='recipienttype').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='requestcategory').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='communicationmodule').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='requestpriority').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='requeststatus').drop(op.get_bind(), checkfirst=True)
