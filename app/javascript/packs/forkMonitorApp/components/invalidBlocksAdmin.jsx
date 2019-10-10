import React from 'react';
import {
  List,
  Edit,
  SimpleForm,
  Toolbar,
  DeleteButton,
  Datagrid,
  DateField,
  TextField,
  NumberField,
  DateInput
} from 'react-admin';

import TimestampField from './timestampField';

export const InvalidBlockList = props => (
    <List {...props} 
        sort={{ field: "block.height"}}
        bulkActionButtons={false}
        >
        <Datagrid rowClick="edit">
            <TextField source="coin" sortable={false} />
            <NumberField source="block.height" sortable={false} options={{ useGrouping: false }}  />
            <TextField source="node.name_with_version" sortable={false} />
            <TextField source="block.hash" sortable={false} />
            <TimestampField source="block.timestamp" sortable={false} />
            <DateField source="dismissed_at" showTime sortable={false} />
        </Datagrid>
    </List>
);

const InvalidBlockEditToolbar = props => (
    <Toolbar {...props} >
      { props.record.dismissed_at == null &&
          <DeleteButton label="Dismiss"/>
      }
    </Toolbar>
);

export const InvalidBlockEdit = props => (
    <Edit {...props}>
        <SimpleForm toolbar={<InvalidBlockEditToolbar />}>
          <TextField source="coin" readOnly />
          <NumberField source="block.height" readOnly />
          <TextField source="node.name_with_version" readOnly />
          <TextField source="block.hash" readOnly />
          <TimestampField source="block.timestamp" readOnly />
          <DateField source="dismissed_at" showTime readOnly />
        </SimpleForm>
    </Edit>
);
