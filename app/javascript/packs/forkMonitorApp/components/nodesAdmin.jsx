import React from 'react';
import {
  List,
  Edit,
  Create,
  Datagrid,
  BooleanField,
  TextField,
  DateField,
  NumberField,
  SimpleForm,
  NumberInput,
  TextInput,
  BooleanInput
} from 'react-admin';

export const NodeList = props => (
    <List {...props}
        sort={{ field: "id"}}
        >
        <Datagrid rowClick="edit">
            <NumberField source="id" />
            <TextField source="coin" />
            <TextField source="name" />
            <BooleanField source="is_core" />
            <TextField source="version" />
            <DateField source="unreachable_since" />
            <NumberField source="best_block.height" />
            <NumberField source="common_block.height" />
        </Datagrid>
    </List>
);

export const NodeEdit = props => (
    <Edit {...props}>
        <SimpleForm>
            <TextInput source="coin" />
            <TextInput source="name" />
            <BooleanInput source="is_core" />
            <TextInput source="rpchost" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <NumberInput source="common_block" />
        </SimpleForm>
    </Edit>
);

export const NodeCreate = props => (
    <Create {...props}>
        <SimpleForm>
            <TextInput source="coin" />
            <TextInput source="name" />
            <BooleanInput source="is_core" />
            <TextInput source="rpchost" />
            <TextInput source="rpcuser" />
            <TextInput source="rpcpassword" />
            <NumberInput source="common_block" />
        </SimpleForm>
    </Create>
);
